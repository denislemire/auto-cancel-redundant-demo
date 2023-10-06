#!/bin/bash

## Get the name of the workflow and the related pipeline number
curl --header "Circle-Token: $MyToken" --request GET "https://circleci.com/api/v2/workflow/${CIRCLE_WORKFLOW_ID}" -o current_workflow.json
WF_NAME=$(jq -r '.name' current_workflow.json)
CURRENT_PIPELINE_NUM=$(jq -r '.pipeline_number' current_workflow.json)

## Get the IDs of pipelines created by the current user on the same branch. (Only consider pipelines that have a pipeline number inferior to the current pipeline)
PIPE_IDS=$(curl --header "Circle-Token: $MyToken" --request GET "https://circleci.com/api/v2/project/gh/$CIRCLE_PROJECT_USERNAME/$CIRCLE_PROJECT_REPONAME/pipeline?branch=$CIRCLE_BRANCH"|jq -r --arg CIRCLE_USERNAME "$CIRCLE_USERNAME" --argjson CURRENT_PIPELINE_NUM "$CURRENT_PIPELINE_NUM" '.items[]|select(.state == "created")|select(.trigger.actor.login == $CIRCLE_USERNAME)|select(.number < $CURRENT_PIPELINE_NUM)|.id')

## Get the IDs of currently running/on_hold workflows that have the same name as the current workflow, in all previously created pipelines.
if [ ! -z "$PIPE_IDS" ]; then
  for PIPE_ID in $PIPE_IDS
  do
    curl --header "Circle-Token: $MyToken" --request GET "https://circleci.com/api/v2/pipeline/${PIPE_ID}/workflow"|jq -r --arg WF_NAME "${WF_NAME}" '.items[]|select(.status == "on_hold" or .status == "running") | select(.name == $WF_NAME) | .id' >> WF_to_cancel.txt
  done
fi

## Cancel any currently running/on_hold workflow with the same name
if [ -s WF_to_cancel.txt ]; then
  echo "Cancelling the following workflow(s):"
  cat WF_to_cancel.txt 
  while read WF_ID;
    do
      curl --header "Circle-Token: $MyToken" --request POST https://circleci.com/api/v2/workflow/$WF_ID/cancel
    done < WF_to_cancel.txt
  ## Allowing some time to complete the cancellation
  sleep 2
  else
    echo "Nothing to cancel"
fi
