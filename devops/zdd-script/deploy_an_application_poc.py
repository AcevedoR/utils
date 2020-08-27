import argparse
import httpx
import subprocess
import os
from datetime import datetime
import contextvars
import asyncio
from urllib.parse import quote

DEFAULT_WAITING_TIME = 120
# 120s seems enough :
#  - 30s for Eureka server
#  - 30s for Eureka client
#  - 30s for Ribbon load balancer (30) caches
#  - 30s so that longer requests can terminate
VERBOSE = False
SKIP_INSTALL = False

DELAY_BETWEEN_START_UPS = 120

httpx_async = httpx.AsyncClient(
    # 60s for connect timeout, 10s for read, write and pool timeouts
    timeout=httpx.Timeout(10, connect_timeout=60)
)

eurekas_urls = {
    'some-env': 'some-eureka-discovery-url'
}
infrastructure_root_dir = ".."
current_directory_name = None

# this should be a list of strings, each item is a tag for the logger
logging_context = contextvars.ContextVar('Context of logging')

errors = []


def main(env: str, desired_instances_number, app_names, waiting_time=DEFAULT_WAITING_TIME, verbose=VERBOSE, skip_install=SKIP_INSTALL):
    # TODO: remove desired_instances_number argument
    global current_directory_name
    current_directory_name = os.path.dirname(__file__)

    logging_context.set([])

    log(open(get_full_path(current_directory_name, "banner.txt"), "r").read())
    log(f'Lauching ZDD for applications : {app_names}')
    log(f'For env : {env}')
    log(f'With waiting_time : {waiting_time}')
    log(f'With verbose : {verbose}')
    log(f'With skip install : {skip_install}')

    async_event_loop = asyncio.get_event_loop()
    results = async_event_loop.run_until_complete(
        asyncio.gather(
            *[
                install_and_zdd_app(app_name, env, waiting_time, verbose, skip_install, index) for index, app_name in enumerate(app_names)
            ]
        )
    )
    async_event_loop.close()

    log('--------------------------- RESULTS ---------------------------')
    if len(errors) == 0:
        log(f'Script was successful !')
    else:
        log(f'During the script execution there was {len(errors)} errors !')
        log('\n'.join(errors))
        raise Exception("some errors occured")


async def install_and_zdd_app(app_name, env: str, waiting_time, verbose, skip_install: bool, index: int):

    # add an increasing delay to avoid port conflicts between microservices
    await asyncio.sleep(DELAY_BETWEEN_START_UPS * index)

    short_app_name = app_name.replace('some-prefix-', '')
    logging_context.set([short_app_name])
    log(f'Deploying {app_name} on {env}')

    # first, we keep only one instance up to prevent memory issues
    instances_before_install = await get_instances(env, app_name)
    await stop_extra_instances(env, app_name, instances_before_install[1:], waiting_time)

    if not skip_install:
        ansible_install_application(env, app_name)

    instances_before_install = await get_instances(env, app_name)

    ansible_start_ms_instance(env, app_name)

    await stop_extra_instances(env, app_name, instances_before_install, waiting_time)


async def stop_extra_instances(env: str, app_name: str, instances_to_stop: list, waiting_time):
    short_app_name = app_name.replace('some-prefix-', '')
    if await at_least_one_instance_is_up_except(env, app_name, instances_to_stop):
        for instance in instances_to_stop:
            logging_context.set(
                [short_app_name, instance["instanceId"], 'stop'])
            await stop_instance(env, app_name, instance, waiting_time)


def ansible_install_application(env: str, application_name):
    old_logging_context = logging_context.get()
    logging_context.set(logging_context.get() + ['install'])
    launch_process(
        f'ansible-playbook {get_infrastructure_root_path()}/playbooks/{application_name}.yml '
        f'-i {get_infrastructure_root_path()}/inventory/{env}/hosts '
        f'--tags prepare')
    logging_context.set(old_logging_context)


def ansible_start_ms_instance(env: str, app_name):
    log(f"starting {app_name}")
    old_logging_context = logging_context.get()
    logging_context.set(logging_context.get() + ['start'])
    launch_process(
        f'ansible-playbook {get_infrastructure_root_path()}/playbooks/{app_name}.yml '
        f'-i {get_infrastructure_root_path()}/inventory/{env}/hosts '
        f'--tags start')
    logging_context.set(old_logging_context)


async def stop_instance(env, app_name, instance, waiting_time):
    if await pause_eureka_instance(env, app_name, instance) is not None:
        old_instance = instance["instanceId"]
        log(f'Waiting {waiting_time}s for requests to finish on instance N > {old_instance}')
        await asyncio.sleep(waiting_time)
        await shutdown_eureka_instance(env, app_name, instance)


def launch_process(command):
    log(command)
    p = subprocess.Popen(command, shell=True,
                         stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    for line in p.stdout.readlines():
        log(line.decode('UTF-8').rstrip()),
    retval = p.wait()
    if retval != 0:
        log(f'Command {command} failed with exit status {str(retval)}')
        exit(retval)


async def get_instances(env: str, app_name: str) -> list:

    headers = {'content-type': "application/json",
               'accept': 'application/json'}
    eureka_apps_url = f'{eurekas_urls[env]}/eureka/apps/{app_name}'
    log(f'GET:{eureka_apps_url}')

    try:
        response = await httpx_async.get(eureka_apps_url, headers=headers)
    except Exception as e:
        error_detail = getattr(e, 'message', repr(e))
        log_error(
            app_name, f'GET:{eureka_apps_url} failed with error: {error_detail}')
        return []

    if response.status_code != 200:
        log_error(
            app_name, f'GET:{eureka_apps_url} returned {response.status_code} and message : {response.text}')
        return []

    instances = response.json()['application']['instance']
   
    instances_with_status = [f'{instance["instanceId"]}:{instance["status"]}' for instance in instances]
    
    log(f'GET:{eureka_apps_url} returned instances {instances_with_status}')
    
    return instances


async def is_eureka_instance_up(env, app_name, instance):

    if instance['status'] != 'UP':
        return False

    health_url = f'{eurekas_urls[env]}/forward/app/{app_name}/instance/{quote(instance["instanceId"])}/health'
    log(f'GET:{health_url}')

    headers = {'content-type': 'application/json',
               'accept': 'application/json'}
    try:
        response = await httpx_async.get(health_url, headers=headers)
    except Exception:
        return False
    return response.status_code == 200


async def at_least_one_instance_is_up_except(env, app_name, old_instances: list):
 
    old_instance_ids = [instance["instanceId"] for instance in old_instances]

    log(f"Wait until at least one instance is UP besides {old_instance_ids}")

    instance_is_up = False
    loop_count = 0

    while instance_is_up == False and loop_count < 20:

        await asyncio.sleep(5)
        loop_count += 1

        instances = await get_instances(env, app_name)

        for instance in instances:
            if instance['instanceId'] not in old_instance_ids and await is_eureka_instance_up(env, app_name, instance):
                instance_is_up = True

    if instance_is_up:
        log(f"At least one instance is UP besides {old_instance_ids}")
    else:
        log_error(app_name, f"No instances UP besides {old_instance_ids}, "
                  f"therefore we are not pausing/shutting down the only one left !")

    return instance_is_up


async def pause_eureka_instance(env, app_name, instance):
    log(f'PAUSE instance N > {instance["instanceId"]}')
    headers = {'content-type': "application/json",
               'accept': 'application/json'}
    request = f'{eurekas_urls[env]}/forward/app/{app_name}/instance/{quote(instance["instanceId"])}/pause'
    return await post(app_name, headers, request)


async def shutdown_eureka_instance(env, app_name, instance):
    log(f'SHUTDOWN instance N > {instance["instanceId"]}')
    headers = {'content-type': "application/json",
               'accept': 'application/json'}
    request = f'{eurekas_urls[env]}/forward/app/{app_name}/instance/{quote(instance["instanceId"])}/shutdown'
    await post(app_name, headers, request)


async def post(app_name, headers, request):
    response = None
    log(f'POST:{request}')
    try:
        response = await httpx_async.post(request, headers=headers)
        if response.status_code != 200:
            log_error(
                app_name, f'POST:{request} returned {response.status_code} and message : {response.text}')
    except Exception as e:
        log_error(app_name, f'POST:{request} failed with error : {str(e)}')
    return response


def get_full_path(current_dir_name, relative_path):
    return os.path.join(current_dir_name, relative_path)


def get_infrastructure_root_path():
    return get_full_path(current_directory_name, infrastructure_root_dir)


def log(entry):
    current_time = datetime.now().strftime("%H:%M:%S.%f")[:-3]
    tags = ''.join('[{}]'.format(t) for t in logging_context.get())
    # to parse it use "(^\[.*?\])\ "
    print(f'[{current_time}]{tags} {entry}')


def log_error(app_name: str, message: str):
    old_logging_context = logging_context.get()
    logging_context.set(logging_context.get() + ['ERROR'])
    log(message)
    logging_context.set(old_logging_context)
    global errors
    errors.append(f'{app_name} - {message}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('environment', metavar='environment', type=str,
                        help='The environment to deploy the app on')
    parser.add_argument('desired_instances_number', metavar='desired_instances_number', type=int,
                        help='The minimum number of instances you want to have for this app in the end of the deployment')
    parser.add_argument('applications_names', metavar='applications_names', type=str, nargs='+',
                        help='List of names of the applications you want to deploy')
    parser.add_argument('-w', '--waiting_time', metavar='waiting_time', type=int, default=DEFAULT_WAITING_TIME,
                        help='Time to wait for each cache to clear, multiply by 2 for each instance')
    parser.add_argument('-v', '--verbose', dest='verbose', action='store_true',
                        help='Should the app be on verbose or not')
    parser.add_argument('-s', '--skip-install', dest='skip_install', action='store_true',
                        help='Skip Ansible install or not')
    args = parser.parse_args()
    main(args.environment, args.desired_instances_number, args.applications_names, waiting_time=args.waiting_time,
         verbose=args.verbose, skip_install=args.skip_install)
