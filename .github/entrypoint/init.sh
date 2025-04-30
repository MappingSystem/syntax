#!/usr/bin/env bash
# Structure: Cell Types – Modulo 6
# https://www.hexspin.com/proof-of-confinement/

hr='------------------------------------------------------------------------------------'

git config --global user.name "${GITHUB_ACTOR}"
git config --global user.email "${GITHUB_ACTOR}@users.noreply.github.com"

git config --global --add safe.directory "${GITHUB_WORKSPACE}"
[[ "$RUNNER_OS" == "Windows" ]] && YQ=$(choco install yq)
[[ "$RUNNER_OS" == "Windows" ]] && git config --global core.safecrlf false
       
git config --global credential.helper store
echo "https://${GITHUB_ACTOR}:${GH_TOKEN}@github.com" > ~/.git-credentials

export RERUN_RUNNER=$(curl -s -H "Authorization: token $GH_TOKEN" -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/${GITHUB_REPOSITORY}/actions/variables/RERUN_RUNNER" | jq -r '.value')
export TARGET_REPOSITORY=$(curl -s -H "Authorization: token $GH_TOKEN" -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/${GITHUB_REPOSITORY}/actions/variables/TARGET_REPOSITORY" | jq -r '.value')
  
echo 'RERUN_RUNNER='${RERUN_RUNNER} >> ${GITHUB_ENV}
echo 'TARGET_REPOSITORY='${TARGET_REPOSITORY} >> ${GITHUB_ENV}

TARGET_REPO="https://${GITHUB_ACTOR}:${GH_TOKEN}@github.com/${TARGET_REPOSITORY}.git"
REMOTE_REPO="https://${GITHUB_ACTOR}:${GH_TOKEN}@github.com/${GITHUB_REPOSITORY}.git"

API_URL="https://api.github.com/users/eq19/events/public"
COMMIT=$(curl -s $API_URL | jq -r 'map(select(.type == "PushEvent")) | .[0].payload.commits[0].message')

# Remove double quotes using parameter expansion
LATEST_COMMIT="${COMMIT//\"/}"

if [[ -z "$LATEST_COMMIT" ]] || [[ "$LATEST_COMMIT" == "null" ]]; then
  echo 'LATEST_COMMIT="update by workspace"' >> ${GITHUB_ENV}
else
  echo 'LATEST_COMMIT='$LATEST_COMMIT >> ${GITHUB_ENV}
fi

if [[ -z ${PASS} ]] || [[ "${PASS}" == "true" ]]; then

  echo 'TARGET_REPO='${TARGET_REPO} >> ${GITHUB_ENV}
  echo 'REMOTE_REPO='${REMOTE_REPO} >> ${GITHUB_ENV}

  if [[ -f /home/runner/_site/_config.yml ]]; then
    cat /home/runner/_site/_config.yml
    FOLDER=$(yq '.span' /home/runner/_site/_config.yml)
    export FOLDER=$(eval echo $FOLDER)
  elif [[ -f /home/runner/_site/.env ]]; then
    set -a && . /home/runner/_site/.env && set +a
  fi

  if [[ -d $1/user_data/strategies ]]; then
    echo -e "\n$hr\nCONFIG\n$hr"
    mv -f /home/runner/work/_actions/eq19/eq19/v2/.github/templates/jekyll_config.yml $RUNNER_TEMP/_config.yml
    export PATH=/home/runner/work/_actions/eq19/eq19/v2/.github/entrypoint:$PATH && artifact.sh

    # Loop through all repos and cancel runs except current one
    #ALL_REPOS=""
    #ORGS=$(gh api user/orgs --jq '.[].login')
    #CURRENT_REPO=$(gh repo view --json nameWithOwner -q '.nameWithOwner')
    #ALL_REPOS+=$(gh repo list --limit 1000 --json nameWithOwner -q '.[].nameWithOwner')
    #for org in $ORGS; do ALL_REPOS+=$(gh repo list $org --limit 1000 --json nameWithOwner -q '.[].nameWithOwner'); done
    #for REPO in $ALL_REPOS; do
      #if [ "$REPO" != "$CURRENT_REPO" ]; then
        #RUNS=$(gh api "repos/$REPO/actions/runs?status=in_progress" --jq '.workflow_runs[].id')
        #RUNS+=" $(gh api "repos/$REPO/actions/runs?status=queued" --jq '.workflow_runs[].id')"
        #for RUN_ID in $RUNS; do gh api -X POST "repos/$REPO/actions/runs/$RUN_ID/force-cancel"; done
      #fi
    #done

    PARAMS_JSON=$(curl -s -H "Authorization: token $GH_TOKEN" -H "Accept: application/vnd.github.v3+json" \
      "https://api.github.com/repos/${GITHUB_REPOSITORY}/actions/variables/PARAMS_JSON" | jq -r '.value')
    echo "${PARAMS_JSON}" | jq '.' > $1/user_data/strategies/fibbo.json
    if jq empty < $1/user_data/strategies/fibbo.json; then
      echo -e "\n$hr\nPARAMETERS\n$hr"
      cat $1/user_data/strategies/fibbo.json
      gh variable set PARAMS_JSON --repo ${TARGET_REPOSITORY} --body "${PARAMS_JSON}"
    else
      echo "Invalid JSON"
    fi
  fi
  echo -e "\n$hr\nENVIRONTMENT\n$hr"
  printenv | sort

fi

echo -e "\n$hr\nWORKSPACE\n$hr"
if [[ "${JOBS_ID}" == "1" ]]; then

  cd ${GITHUB_WORKSPACE} && rm -rf .github
  cp -r /home/runner/work/_actions/eq19/eq19/v2/.github .
  chown -R "$(whoami)" .github

  git remote set-url origin ${REMOTE_REPO}        
  git add . && git commit -m "update workflows" --quiet && git push --quiet

  if [[ $? -eq 0 ]]; then

    #git clone --single-branch --branch gh-pages $REMOTE_REPO gh-pages && cd gh-pages
    #git add . && git commit --allow-empty -m "rerun due to job update" && git push
    curl -s -X POST \
      -H "Authorization: token $GH_TOKEN" \
      -H "Accept: application/vnd.github.v3+json" \
      "https://api.github.com/repos/${GITHUB_REPOSITORY}/dispatches" \
      -d '{"event_type": "retry_workflow", "client_payload": {"original_run_id": "${GITHUB_RUN_ID}"}}'
    exit 1

  else

    cd $1 && javac -d user_data/ft_client/test_client javaCode/Main.java
    cd $GITHUB_WORKSPACE && rm -rf user_data && mv -f $1/user_data . && ls -al .

    # Fetch SHA, encode new content, and update in one step
    gh api --method PUT /repos/${TARGET_REPOSITORY}/contents/.github/workflows/main.yml \
      -f sha="$(gh api /repos/${TARGET_REPOSITORY}/contents/.github/workflows/main.yml --jq '.sha')" \
      -f message="Update file" -f content="$(base64 -w0 .github/workflows/main.yml)" > /dev/null

  fi

elif [[ "${JOBS_ID}" == "2" ]]; then

  ls -alR $GITHUB_WORKSPACE

  echo -e "\n$hr\nGH BRANCHES\n$hr"
  cd $RUNNER_TEMP && mkdir my-project && cd my-project && git init -q
  git remote add source $REMOTE_REPO && git remote add origin $TARGET_REPO

  # Get list of existing target branches (once)
  existing_target_branches=$(git ls-remote --heads origin | awk -F'/' '{print $3}')

  # Fetch only gh- branches from source
  git fetch source 'refs/heads/gh-*:refs/remotes/source/gh-*'

  # Process branches
  for remote_branch in $(git branch -r | grep 'source/gh-'); do
    local_branch=${remote_branch#source/}
  
    if ! grep -q "^$local_branch$" <<< "$existing_target_branches"; then
      git checkout -b "$local_branch" "$remote_branch"
      git push origin "$local_branch"
      echo "Successfully pushed $local_branch to target"
    #else
      #if [[ "$local_branch" == "gh-pages" ]]; then
        # Check if 'docs/' exists in the remote gh-pages tree
        #if ! git ls-tree --name-only origin/gh-pages | grep -q "^docs/"; then
          #echo "Re-pushed local gh-pages with docs"
          #git push origin --delete gh-pages
          #git push origin gh-pages
        #fi
      #fi
    fi
  done

elif [[ "${JOBS_ID}" == "3" ]]; then

  cd /home/runner/_site && rm -rf README.md docs && gist.sh ${BASE} $(pwd)

  if [[ "${WIKI}" != "${BASE}" ]]; then
    find . -type d -name "${FOLDER}" -prune -exec sh -c 'gist.sh ${WIKI} "$1"' sh {} \;
  fi

else

  cd ${RUNNER_TEMP//\\//} && rm -rf gh-source
  git clone --single-branch --branch gh-source $TARGET_REPO gh-source
  
  cd ${GITHUB_WORKSPACE//\\//}
  find -not -path "./.git/*" -not -name ".git" -delete

  rm -rf ${RUNNER_TEMP//\\//}/gh-source/.git
  shopt -s dotglob && mv -f ${RUNNER_TEMP//\\//}/gh-source/* . && ls -lR .

fi

if [[ -z ${PASS} ]] || [[ "${PASS}" == "true" ]]; then
  echo -e "\n$hr\nGITHUB CONTEXT\n$hr"
fi
