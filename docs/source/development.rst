+++++++++++
Development
+++++++++++

-----------------------
Development environment
-----------------------

Set up development environment on Mac and Linux

The only prereq is that uv is installed.


.. code-block:: shell-session

    user@DEVMACHINE123 % uv sync --group dev
    user@DEVMACHINE123 % source .venv/bin/activate


Add pre-commit hooks to help verify code quality before changes are commited.

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
