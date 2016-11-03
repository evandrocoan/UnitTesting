import sublime
import sublime_plugin
import sys
import os
import logging
from unittest import TextTestRunner
from .core import TestLoader
from .core import DeferringTextTestRunner
from .mixin import UnitTestingMixin
from .const import DONE_MESSAGE
import threading

version = sublime.version()


class UnitTestingCommand(sublime_plugin.ApplicationCommand, UnitTestingMixin):

    def run(self, package=None, **kargs):

        if not package:
            self.prompt_package(lambda x: self.run(x, **kargs))
            return
        package, pattern = self.input_parser(package)
        settings = self.load_settings(package, pattern=pattern, **kargs)
        stream = self.load_stream(package, settings["output"])

        if settings["async"]:
            threading.Thread(target=lambda: self.unit_testing(stream, package, settings)).start()
        else:
            self.unit_testing(stream, package, settings)

    def unit_testing(self, stream, package, settings, cleanup_hooks=[]):
        stdout = sys.stdout
        stderr = sys.stderr
        handler = logging.StreamHandler(stream)
        if settings["capture_console"]:
            logging.root.addHandler(handler)
            sys.stdout = stream
            sys.stderr = stream
        testRunner = None

        try:
            # use custom loader which support ST2 and reloading modules
            self.remove_test_modules(package, settings["tests_dir"])
            loader = TestLoader(settings["deferred"])
            test = loader.discover(os.path.join(
                sublime.packages_path(), package, settings["tests_dir"]), settings["pattern"]
            )
            # use deferred test runner or default test runner
            if settings["deferred"]:
                testRunner = DeferringTextTestRunner(stream, verbosity=settings["verbosity"])
            else:
                testRunner = TextTestRunner(stream, verbosity=settings["verbosity"])

            testRunner.run(test)

        except Exception as e:
            if not stream.closed:
                stream.write("ERROR: %s\n" % e)
            # force clean up
            testRunner = None
        finally:
            def cleanup(status=0):
                if not settings["deferred"] or not testRunner or \
                        testRunner.finished or status > 600:
                    self.remove_test_modules(package, settings["tests_dir"])
                    for hook in cleanup_hooks:
                        hook()
                    stream.write("\n")
                    stream.write(DONE_MESSAGE)
                    stream.close()
                    if settings["capture_console"]:
                        sys.stdout = stdout
                        sys.stderr = stderr
                        # remove stream set by logging.root.addHandler
                        logging.root.removeHandler(handler)
                else:
                    sublime.set_timeout(lambda: cleanup(status+1), 500)

            cleanup()
