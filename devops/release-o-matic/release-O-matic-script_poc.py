#!/usr/bin/python
# -*- coding: utf-8 -*-
import imp
import jenkins
import time
from argparse import ArgumentParser
from texttable import Texttable
import os

jenkins_url = 'some-jenkins-url'
jenkins_user = 'jenkins'
jenkins_user_api_token = "some-jenkins-token"

current_directory_name = None
list_projects_to_release_script_location = "../list-projects-to-release/list-projects-to-release-script.py"
list_projects_to_release_script_location_override = None

is_production_mode = False
print_colors = False
hr_size = 74

# because their release process are special
projects_to_skip = ['some-project-to-skip']
projects_to_skip_input = []
projects_name_from_git_to_jenkins = {
    'some-project-git-name':'some-project-jenkins-name'
}


def main(options=None):
    global current_directory_name
    current_directory_name = os.path.dirname(__file__)

    if options:
        if options.list_projects_to_release_script_location_override:
            global list_projects_to_release_script_location_override
            list_projects_to_release_script_location_override = options.list_projects_to_release_script_location_override
        if options.print_colors:
            global print_colors
            print_colors = options.print_colors
        if options.is_production_mode:
            global is_production_mode
            is_production_mode = options.is_production_mode
        if options.projects_to_skip_input:
            global projects_to_skip_input
            projects_to_skip_input = options.projects_to_skip_input

    list_projects_to_release_script = imp.load_source("list-projects-to-release-script",
                                                      get_list_projects_to_release_script_path())
    projects_to_release = list_projects_to_release_script.main()

    print
    print_banner()
    print

    if is_production_mode is True:
        global jenkins_folder
        jenkins_folder = '3-release'
        print 'Production mode, running in ' + jenkins_folder + ' folder'
    else:
        jenkins_folder = '1-ci'
        print 'Test mode, running in ' + jenkins_folder + ' folder'

    jenkins_server = connect_to_jenkins()

    projects_to_release_count = len(projects_to_release)
    print 'There is ' + str(projects_to_release_count) + ' projects to release'
    current_project_number = 0

    print
    print 'Skipping projects written in this script : '+str(projects_to_skip)
    if projects_to_skip_input:
        print 'Skipping projects passed in --skip-projects : '+str(projects_to_skip_input)

    # Reporting
    job_report_list = {}

    for project in projects_to_release:

        print
        print_hr_big()
        print "Starting " + format_with_color(project, "blue") + " release job"
        print_hr()
        current_project_number += 1
        print 'Project number ' + str(current_project_number) + ' out of ' + str(projects_to_release_count)
        print_hr()

        # Skipping specific projects
        if project in projects_to_skip:
            dummy_build = {'number': -1, 'url': '/'}
            print format_with_color("Skipping project " + project + " because it has a special release process", "yellow")
            dummy_build['status'] = 'SKIPPED'
            dummy_build['failing_cause'] = "Project has a special release process"
            job_report_list[project] = dummy_build
            continue

        # Skipping projects from user input
        if project in projects_to_skip_input:
            dummy_build = {'number': -1, 'url': '/'}
            print format_with_color("Skipping project " + project + " because of user input", "yellow")
            dummy_build['status'] = 'SKIPPED'
            dummy_build['failing_cause'] = "Skipped in script input"
            job_report_list[project] = dummy_build
            continue

        # Transform project name for compatibility with jenkins URLs
        project_jenkins_name = projects_name_from_git_to_jenkins.get(project)
        if project_jenkins_name != None:
            project = project_jenkins_name

        job_name = project + "-release"
        full_job_name = jenkins_folder + '/' + job_name  # keep in mind that we use Jenkins Cloudbees Folders plugins
        simulated_jenkins_job_url = simulate_jenkins_job_url(jenkins_folder, job_name)
        print simulated_jenkins_job_url
        print_hr()
        print

        # getting previous job id
        # this is the first call with this url so it can fail
        try:
            previous_build = get_last_build(jenkins_server, full_job_name)
            pass
        except jenkins.JenkinsException, e:
            job_report_list[project] = {'number': -1, 'url': simulated_jenkins_job_url, 'status': 'FAILED',
                                        'failing_cause': 'Could not do first jenkins /job call because : ' + e.message}
            print format_with_color('Jenkins error : ', 'red_background') + e.message
            continue  # skip current iteration

        last_build_completed = get_last_build_completed(jenkins_server, full_job_name)

        if previous_build['number'] == last_build_completed['number']:

            # actualy launching the job
            # this shitty trick is to let the module call the /buildWithParameters url
            jenkins_server.build_job(full_job_name, {'dummy_param': 'dummy_value'})

            current_build = get_last_build(jenkins_server, full_job_name)

            print 'Waiting for build to start'
            i = 1
            while current_build['number'] == previous_build['number']:
                i = print_loading_line(i)
                time.sleep(1)
                current_build = get_last_build(jenkins_server, full_job_name)

            print
            print
            print '\tcurrent_build :'
            print '\t\tnumber : ' + str(current_build['number'])
            print '\t\turl : ' + str(current_build['url'])
            print
            print 'Job is running'
            print

            last_build_completed = get_last_build_completed(jenkins_server, full_job_name)

            print 'Waiting for build to finish running'
            i = 1
            while last_build_completed['number'] <= previous_build['number']:
                i = print_loading_line(i)
                time.sleep(1)
                last_build_completed = get_last_build_completed(jenkins_server, full_job_name)

            print
            print
            print 'Build finished'
            print
            print_hr()
            print

            last_successful_build = get_last_build_successful(jenkins_server, full_job_name)
            if last_successful_build:
                print 'last_successful_build :'
                print '\tnumber : ' + str(last_successful_build['number'])
                print '\turl : ' + str(last_successful_build['url'])
            else:
                print 'No last_successful_build'
            print
            last_unsuccessful_build = get_last_build_unsuccessful(jenkins_server, full_job_name)
            if last_unsuccessful_build:
                print 'last_unsuccessful_build :'
                print '\tnumber : ' + str(last_unsuccessful_build['number'])
                print '\turl : ' + str(last_unsuccessful_build['url'])
            else:
                print 'No last_unsuccessful_build'
            print
            print_hr()
            print
            if last_successful_build is not None and last_successful_build['number'] == current_build['number']:
                print format_with_color("Build successful", "green")
                print "\turl : " + str(current_build['url'])
                current_build['status'] = 'SUCCESSFUL'

            elif last_unsuccessful_build is not None and last_unsuccessful_build['number'] == current_build['number']:
                print format_with_color("Build failed", "red_background")
                print "\turl : " + str(current_build['url'])
                current_build['status'] = 'FAILED'
                current_build['failing_cause'] = 'Jenkins build failed'

            else:
                print format_with_color(
                    "Something went wrong, current build is not the last failed of successful one !", "red_background")
                current_build['status'] = 'FAILED'
                current_build['failing_cause'] = 'current build is not the last failed of successful one'

            job_report_list[project] = current_build

        else:
            print format_with_color("Skipping project " + full_job_name + " because there is already a build running",
                                    "yellow")
            previous_build['status'] = 'SKIPPED'
            previous_build['failing_cause'] = 'Build ' + str(previous_build['number']) + ' is running while ' + str(
                last_build_completed['number']) + ' is the last one completed'
            job_report_list[project] = previous_build
            print 'Current build running :'
            print '\tnumber : ' + str(previous_build['number'])
            print '\turl : ' + str(previous_build['url'])
            print "Last completed build :"
            print '\tnumber : ' + str(last_build_completed['number'])
            print '\turl : ' + str(last_build_completed['url'])

    print
    print_hr_big()
    print 'All ' + str(projects_to_release_count) + ' projects were processed'
    print_hr_big()
    print

    table = Texttable()
    table.set_cols_width([20, 100, 10, 50])
    rows = [['project', 'url', 'status', 'reason']]

    has_errors = False
    for project, build in job_report_list.iteritems():
        if build['status'] == "FAILED":
            has_errors = True
        if ('failing_cause') in build:
            cause = build['failing_cause']
        else:
            cause = ""
        rows.append([project, build['url'], get_status_colored(build['status']), cause])

    table.add_rows(rows)
    print(table.draw())

    if has_errors:
        exit(1)
    exit(0)


def get_list_projects_to_release_script_path():
    if list_projects_to_release_script_location_override:
        return list_projects_to_release_script_location_override
    else:
        return get_full_path(list_projects_to_release_script_location)


def get_status_colored(status):
    switcher = {"SUCCESSFUL": "green", "SKIPPED": "yellow", "FAILED": "red_background"}
    return format_with_color(status, switcher.get(status, "Unknown status " + status))


# This is almost the same url used by jenkins module, without the /api at the end
# This is only for display
def simulate_jenkins_job_url(folder, job_name):
    return jenkins_url + '/job/' + folder + '/job/' + job_name


def print_loading_line(i):
    # TODO Do something, working on Ubuntu but not on Jenkins
    # sys.stdout.write('\r' + '\twaiting ' + ('.' * (i % 4)) + '   ')
    # sys.stdout.flush()
    return i + 1


def format_with_color(string, color_name):
    switcher = {"green": "\033[32m", "yellow": "\033[33m", "red_background": "\033[41m", "blue": "\033[34m",
                "blue_background": "\033[44m"}
    ANSI_prefix = switcher.get(color_name, "Unknown color")
    ANSI_suffix = '\033[0m'
    if print_colors:
        return ANSI_prefix + string + ANSI_suffix
    else:
        return string


def get_job(jenkins_server, full_job_name):
    return jenkins_server.get_job_info(full_job_name)


def get_last_build(jenkins_server, full_job_name):
    return get_job(jenkins_server, full_job_name)['lastBuild']


def get_last_build_completed(jenkins_server, full_job_name):
    return get_job(jenkins_server, full_job_name)['lastCompletedBuild']


def get_last_build_successful(jenkins_server, full_job_name):
    return get_job(jenkins_server, full_job_name)['lastSuccessfulBuild']


def get_last_build_unsuccessful(jenkins_server, full_job_name):
    return get_job(jenkins_server, full_job_name)['lastUnsuccessfulBuild']


def connect_to_jenkins():
    server = jenkins.Jenkins(jenkins_url, username=jenkins_user, password=jenkins_user_api_token)
    user = server.get_whoami()
    version = server.get_version()
    print('Hello %s from Jenkins %s' % (user['fullName'], version))
    return server


def print_hr():
    print '-' * hr_size


def print_hr_big():
    print '#' * hr_size


def print_banner():
    print open(get_full_path("banner.txt"), "r").read()


def get_full_path(relative_path):
    return os.path.join(current_directory_name, relative_path)


if __name__ == '__main__':
    parser = ArgumentParser()
    parser.add_argument("-c", "--print-colors", dest="print_colors", default=False,
                        action="store_true", help="Enable ANSI color printing")
    parser.add_argument("-p", "--production-mode", dest="is_production_mode", default=False,
                        action="store_true",
                        help="Enable production mode, changes job folder (to '3-release' instead of default '1-ci')")
    parser.add_argument("-s", "--list-projects-to-release-script-location",
                        dest="list_projects_to_release_script_location_override",
                        default=None, action="store", type=str,
                        help="Location of list-projects-to-release-script. Full path with extension required.")
    parser.add_argument("-S", "--skip-projects",
                        dest="projects_to_skip_input",
                        default=None, action="store", type=str,
                        help="List of projects to skip",
                        nargs='+')
    args = parser.parse_args()
    main(options=args)
