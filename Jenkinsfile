pipeline {
    agent none
    parameters {
        booleanParam(name: 'RUN_CHECKS', defaultValue: true, description: 'Run checks on code')
    }
    stages {
        stage('Building and Testing'){
            when{
                equals expected: true, actual: params.RUN_CHECKS
            }
            stages{
                stage('Setup'){
                    stages{
                        stage('Setup Testing Environment'){
                            steps{
                                echo 'Create virtual environment'
                            }
                        }
                        stage('Installing project as editable module'){
                            steps{
                               echo 'Building debug build with coverage data'
                            }
                        }
                    }
                }
                stage('Code Quality') {
                    when{
                        equals expected: true, actual: params.RUN_CHECKS
                    }
                    stages{
                        stage('Running Tests'){
                            parallel {
                                stage('Running Unit Tests'){
                                    steps{
                                        echo 'pytest'
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}