import argparse
import requests

eurekas_urls = {
    'some-env': 'some-eureka-api-discovery-url'
}
json_headers = {'content-type': "application/json", 'accept': 'application/json'}


def main(env):
    for app in get_apps(env):
        clean_app_for_env(app['name'], env)


def clean_app_for_env(app_name, env):
    print_hr()
    instances = get_app(app_name, env)['application']['instance']
    print(f'instances count: {len(instances)}')

    for instance in instances:
        print(f'instance id: {instance["instanceId"]}, status: {instance["status"]}')
        if instance["status"] == 'DOWN':
            shutdown_instance(instance)


def get_app(app_name, env):
    eureka_app_url = f'{eurekas_urls[env]}/apps/{app_name}'

    print(f'GET:{eureka_app_url}')
    try:
        response = requests.get(eureka_app_url, headers=json_headers)
    except Exception as e:
        print(f'GET:{eureka_app_url} failed with error : {str(e)}')
        return {'application': {'instance': []}}

    if response.status_code != 200:
        print(f'GET:{eureka_app_url} returned {response.status_code} and message : {response.text}')
        return {'application': {'instance': []}}

    return response.json()


def shutdown_instance(instance):
    shutdown_url = f'{instance["homePageUrl"]}actuator/shutdown'
    print(f'POST:{shutdown_url}')
    try:
        response = requests.post(shutdown_url, headers=json_headers)
        if response.status_code != 200:
            print(f'POST:{shutdown_url} returned {response.status_code} and message : {response.text}')
    except Exception as e:
        print(f'POST:{shutdown_url} failed with error : {str(e)}')


def get_apps(env):
    eureka_apps_url = f'{eurekas_urls[env]}/apps'

    print(f'GET:{eureka_apps_url}')
    response = requests.get(eureka_apps_url, headers=json_headers)

    return response.json()['applications']['application']


def print_hr():
    print('------------------------------------------')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('environment', metavar='environment', type=str,
                        help='The environment to do the cleaning on')
    args = parser.parse_args()
    main(args.environment)
