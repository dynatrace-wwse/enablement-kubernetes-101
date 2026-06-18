#!/bin/bash
#loading functions to script
export SECONDS=0
source .devcontainer/util/source_framework.sh

# Validate the Dynatrace credentials declared in devcontainer.json (secrets).
# Codespaces silently omits unset secrets, so without this the container can
# half-create and later DT deploy steps fail with no clear cause. Fail loudly
# instead. The validator logs missing vars by name only (never the values).
variablesNeeded DT_ENVIRONMENT:true DT_OPERATOR_TOKEN:true DT_INGEST_TOKEN:false || exit 1

setUpTerminal

# Dynamically install an SSH server so `gh codespace ssh` can attach a terminal.
# Custom function declared in util/my_functions.sh (proving on-demand tool load
# for the Enablement App Codespace terminal relay).
sshd

startK3dCluster

installK9s

#TODO: BeforeGoLive: uncomment this. This is only needed for professors to have the Mkdocs live in the container

#installMkdocs


# Dynatrace Operator can be deployed automatically
#dynatraceDeployOperator

# You can deploy CNFS or AppOnly
#deployCloudNative
#deployApplicationMonitoring

# In here you deploy the Application you want
# The TODO App will be deployed as a sample
deployTodoApp

# The Astroshop keeping changes of demo.live needs certmanagerdocker
#certmanagerInstall
#certmanagerEnable
#deployAstroshop

# If you want to deploy your own App, just create a function in the functions.sh file and call it here.
# deployMyCustomApp

# If the Codespace was created via Workflow end2end test will be done, otherwise
# it'll verify if there are error in the logs and will show them in the greeting as well a monitoring 
# notification will be sent on the instantiation details
finalizePostCreation

printInfoSection "Your dev container finished creating"
