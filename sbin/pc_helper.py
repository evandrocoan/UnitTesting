import sublime
import sys
import subprocess
import os


def plugin_loaded():

    pc_settings = sublime.load_settings("PackagesManager.sublime-settings")

    logfile = os.path.join(
        sublime.packages_path(),
        "0_install_package_control_helper",
        "log")

    from DebugTools.all.debug_tools import getLogger
    log = getLogger("UnitTesting.sbin.pc_helper", file=logfile, stdout=True)

    log(1, "TESTING!")
    log(1, "TESTING! logfile to: %s", logfile)

    def kill_subl(restart=False):
        if sublime.platform() == "osx":
            cmd = "sleep 1; killall 'Sublime Text'; sleep 1; "
            if restart:
                cmd = cmd + "osascript -e 'tell application \"Sublime Text\" to activate'"
        elif sublime.platform() == "linux":
            cmd = "sleep 1; killall 'subl'; sleep 1; "
            if restart:
                cmd = cmd + "subl"
        elif sublime.platform() == "windows":
            cmd = "sleep 1 & taskkill /F /im sublime_text.exe & sleep 1 "
            if restart:
                cmd = cmd + "& \"C:\\st\\sublime_text.exe\""

        subprocess.Popen(cmd, shell=True)

    def touch(file_name):
        f = os.path.join(
            sublime.packages_path(),
            "0_install_package_control_helper",
            file_name)
        open(f, 'a').close()

    def check_bootstrap():
        if pc_settings.get("bootstrapped", False):
            touch("bootstrapped")
            kill_subl(True)
        else:
            sublime.set_timeout(check_bootstrap, 5000)

    def check_dependencies():
        if 'PackagesManager' in sys.modules:
            package_control = sys.modules['PackagesManager'].package_control
        else:
            sublime.set_timeout(check_dependencies, 5000)
            return

        manager = package_control.package_manager.PackageManager()
        required_dependencies = set(manager.find_required_dependencies())

        class myPackageCleanup(package_control.package_cleanup.PackageCleanup):

            def finish(self, installed_packages, found_packages, found_dependencies):
                missing_dependencies = required_dependencies - set(found_dependencies)

                if len(missing_dependencies) == 0:
                    touch("success")
                    kill_subl()
                else:
                    print("Unit Testing pc_helper(), missing dependencies: %s" % missing_dependencies)
                    print("required_dependencies: %s" % required_dependencies)
                    print("found_dependencies: %s" % found_dependencies)
                    print("'coverage' in missing_dependencies: %s" % str('coverage' in missing_dependencies))
                    sublime.set_timeout(_check_dependencies, 5000)

        def _check_dependencies():
            myPackageCleanup().run()

        _check_dependencies()

    if not os.path.exists(os.path.join(
            sublime.packages_path(),
            "0_install_package_control_helper",
            "bootstrapped")):
        check_bootstrap()
    else:
        # restart sublime when `sublime.error_message` is run
        def error_message(message):
            print(message)
            kill_subl(True)

        sublime.error_message = error_message
        check_dependencies()
