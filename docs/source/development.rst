+++++++++++
Development
+++++++++++

-----------------------
Development environment
-----------------------

Set up development environment on Mac and Linux

Using UV instead of pip
-----------------------

This way is better and faster than using pip.

.. code-block:: shell-session

    user@DEVMACHINE123 % uv venv
    user@DEVMACHINE123 % source ./venv/bin/activate
    (venv) user@DEVMACHINE123 % uv pip sync requirements-dev.txt
    (venv) user@DEVMACHINE123 % uv pip install -e .

Using pip
---------

If you don't have uv installed:

.. code-block:: shell-session

    user@DEVMACHINE123 % python -m venv .venv
    user@DEVMACHINE123 % source .venv/bin/activate
    (venv) user@DEVMACHINE123 % pip install -r requirements-dev.txt
    (venv) user@DEVMACHINE123 % pip install -e .

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
