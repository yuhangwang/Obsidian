#!/bin/bash

# CONVENTION: The working directory is passed as the first argument.
CHECKOUT=$1
shift

if [ "$CHECKOUT" == "" ]; then
  CHECKOUT=`pwd`
fi
if [ "$JENKINS_GHC" == "" ]; then
  export JENKINS_GHC=7.6.3
fi
if [ -f "$HOME/continuous_testing_setup/rn_jenkins_scripts/acquire_ghc.sh" ]; then
  source $HOME/continuous_testing_setup/rn_jenkins_scripts/acquire_ghc.sh
fi

echo "Running benchmarks remotely on server `hostname`"
set -x

which cabal
cabal --version

unset GHC
unset GHC_PKG
unset CABAL

set -e

# Switch to where the benchmarks are
# ----------------------------------------
cd "$CHECKOUT"/Examples
make build_bench

export TRIALS=1

# Parfunc account, registered app in api console:
CID=905767673358.apps.googleusercontent.com
SEC=2a2H57dBggubW1_rqglC7jtK

# Obsidian doc ID:  
TABID=1TsG043VYLu9YuU58EaIBdQiqLDUYcAXxBww44EG3
# https://www.google.com/fusiontables/DataSource?docid=1TsG043VYLu9YuU58EaIBdQiqLDUYcAXxBww44EG3

# Enable upload of benchmarking data to a Google Fusion Table:
./run_benchmarks.exe --keepgoing --trials=$TRIALS --fusion-upload=$TABID --clientid=$CID --clientsecret=$SEC $*
# Or find table by: --name=Obsidian_bench_data
