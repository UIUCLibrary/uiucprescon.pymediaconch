+++++++++++
Development
+++++++++++

-----------------------
Development environment
-----------------------

Set up development environment on Mac and Linux

The only prereq is that uv is installed.


Setup Development Environment
-----------------------------

.. code-block:: shell-session

    user@DEVMACHINE123 % uv sync --group dev
    user@DEVMACHINE123 % source .venv/bin/activate


Pre-Commit Hooks
----------------

This is optional but recommended. Add pre-commit hooks to help verify code quality before changes are commited.

.. code-block:: shell-session

    (venv) user@DEVMACHINE123 % pre-commit install


-------------
Running tests
-------------

To run test, you need to have pytest installed. If you are using the development environment, it should already be
installed. Tests are run by executing the pytest command.

.. code-block:: shell-session

    (venv) user@DEVMACHINE123 uiucprescon.PyMediaConch % pytest
    ================== test session starts ===================
    platform darwin -- Python 3.13.0, pytest-8.4.1, pluggy-1.6.0
    rootdir: /Users/user/python_projects/uiucprescon.PyMediaConch
    configfile: pyproject.toml
    collected 2 items

    tests/test_simple.py ..                                                                                                                                                                                                          [100%]

    =================== 2 passed in 0.24s ===================


-------------------
Build Documentation
-------------------

The documentation for uiucprescon.pymediaconch contains both user and developer documentation. It is written in
`restructuredText format <https://en.wikipedia.org/wiki/ReStructuredText>`_ and built with
the `Sphinx <https://www.sphinx-doc.org/en/master/>`_ tool.


Only build documentation
------------------------

If you only want to build the documentation without setting up a full development environment, you can do this.


.. code-block:: shell-session

    user@DEVMACHINE123 % uv run --group docs --no-cache --with-editable . sphinx-build docs/source build/docs
    Using CPython 3.11.10
    Creating virtual environment at: .venv
       Building uiucprescon-pymediaconch @ file:///Users/user/PythonProjects/uiucprescon.PyMediaConch
       Building uiucprescon-pymediaconch @ file:///Users/user/PythonProjects/uiucprescon.PyMediaConch
       Building uiucprescon-pymediaconch @ file:///Users/user/PythonProjects/uiucprescon.PyMediaConch
          Built uiucprescon-pymediaconch @ file:///Users/user/PythonProjects/uiucprescon.PyMediaConch
          Built patch-ng==1.18.1
          Built conan==2.20.1
    Installed 58 packages in 684ms
    Running Sphinx v8.2.3
    loading translations [en]... done
    loading pickled environment... done
    building [mo]: targets for 0 po files that are out of date
    writing output...
    building [html]: template versionchanges.html has been changed since the previous build, all docs will be rebuilt
    building [html]: targets for 3 source files that are out of date
    updating environment: 0 added, 2 changed, 0 removed
    reading sources... [100%] development
    looking for now-outdated files... none found
    pickling environment... done
    checking consistency... done
    preparing documents... done
    copying assets...
    copying static files...
    Writing evaluated template result to /Users/user/PythonProjects/uiucprescon.PyMediaConch/build/docs/_static/basic.css
    Writing evaluated template result to /Users/user/PythonProjects/uiucprescon.PyMediaConch/build/docs/_static/language_data.js
    Writing evaluated template result to /Users/user/PythonProjects/uiucprescon.PyMediaConch/build/docs/_static/documentation_options.js
    Writing evaluated template result to /Users/user/PythonProjects/uiucprescon.PyMediaConch/build/docs/_static/alabaster.css
    copying static files: done
    copying extra files...
    copying extra files: done
    copying assets: done
    writing output... [100%] index
    generating indices... genindex done
    writing additional pages... search done
    dumping search index in English (code: en)... done
    dumping object inventory... done
    build succeeded.

    The HTML pages are in build/docs.

Build documentation within a development environment
-----------------------------------------------------

1. Make sure that either the virtual environment is configure with the "dev" or "docs" dependency group

    .. code-block:: shell-session

        user@DEVMACHINE123 % uv sync --group dev
        Using CPython 3.11.10
        Creating virtual environment at: .venv
        Resolved 90 packages in 409ms
              Built uiucprescon-pymediaconch @ file:///Users/user/PythonProjects/uiucprescon.PyMediaConch
              Built patch-ng==1.18.1
              Built conan==2.20.1
        Prepared 58 packages in 3m 05s
        Installed 58 packages in 829ms
         + alabaster==1.0.0
         + babel==2.17.0
         + cachetools==6.2.0
         + certifi==2025.8.3
         + cfgv==3.4.0
         + chardet==5.2.0
        ...


2. With your virtual environment active, run sphinx-build with the first argument being "docs/source" and the second argument
   being the location where to build to.


    .. code-block:: shell-session

        .(venv) user@DEVMACHINE123 % sphinx-build docs/source build/docs
        Running Sphinx v8.2.3
        loading translations [en]... done
        making output directory... done
        building [mo]: targets for 0 po files that are out of date
        writing output...
        building [html]: targets for 3 source files that are out of date
        updating environment: [new config] 3 added, 0 changed, 0 removed
        reading sources... [100%] index
        looking for now-outdated files... none found
        pickling environment... done
        checking consistency... done
        preparing documents... done
        copying assets...
        copying static files...
        Writing evaluated template result to /Users/user/PythonProjects/uiucprescon.PyMediaConch/build/docs/_static/basic.css
        Writing evaluated template result to /Users/user/PythonProjects/uiucprescon.PyMediaConch/build/docs/_static/language_data.js
        Writing evaluated template result to /Users/user/PythonProjects/uiucprescon.PyMediaConch/build/docs/_static/documentation_options.js
        Writing evaluated template result to /Users/user/PythonProjects/uiucprescon.PyMediaConch/build/docs/_static/alabaster.css
        copying static files: done
        copying extra files...
        copying extra files: done
        copying assets: done
        writing output... [100%] index
        generating indices... genindex done
        writing additional pages... search done
        dumping search index in English (code: en)... done
        dumping object inventory... done
        build succeeded.

        The HTML pages are in build/docs.

