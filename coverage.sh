# !/bin/bash
#
# Generate a basic coverage report on local changes to an OSS-Fuzz project.
# This script starts for an empty corpus and runs fuzzers for $fuzz_time
# seconds to generate one. It does not use the existing corpus in OSS-Fuzz,
# as no corpus for new fuzzers will exist locally. Please ensure that
# oss-fuzz-utils and oss-fuzz are sibling directories, and run coverage.sh
# from within the oss-fuzz-utils directory.
#
# Optional: place a corpus for the project in oss-fuzz/corpora/$proj_name.
# This corpus will be used as a basis for each fuzzer's individual corpus.

function usage {
  echo "Usage: sh coverage.sh <project> <[optional] fuzz time (s)>"
  exit 1
}

proj_name=$1
fuzz_time=$2
[ -z "$proj_name" ] && usage
[ -z "$fuzz_time" ] && fuzz_time=60
null_out="/dev/null"

pushd ../oss-fuzz > $null_out

[ ! -d "./corpora/" ] && mkdir corpora
[ ! -d "./corpora/${proj_name}_corpus/" ] && proj_corpus="" \
    || proj_corpus="$(pwd)/corpora/${proj_name}_corpus/"
[ ! -d "./coverage_reports/" ] && mkdir coverage_reports
[ ! -d "./coverage_reports/detailed" ] && mkdir coverage_reports/detailed
[ ! -d "./coverage_reports/detailed/$proj_name" ] \
    && mkdir coverage_reports/detailed/$proj_name \
    || rm -f ./coverage_reports/detailed/$proj_name/*
[ -f "./coverage_reports/${proj_name}_coverage.txt" ] \
    && rm -f ./coverage_reports/${proj_name}_coverage.txt
[ -d "./oss-fuzz" ] && sudo rm -rf oss-fuzz
[ -f "./format.py" ] && sudo rm -f format.py
out_dir="$(pwd)/coverage_reports/detailed/$proj_name"
out_file="$(pwd)/coverage_reports/${proj_name}_coverage.txt"

clear
sudo rm -rf ./build/out/${proj_name}/*
sudo rm -rf ./build/work/${proj_name}/*
sudo rm -rf ./build/corpus/${proj_name}/*

touch format.py
py_format_filepath="$(pwd)/format.py"
function gen_format { echo $1 >> format.py ; }
gen_format "import sys, json"
gen_format "data = json.load(open(sys.argv[1]))['data'][0]['totals']['regions']"
gen_format "print(sys.argv[2] + ': ' + str(data['covered']) + '/' + \\"
gen_format "str(data['count']) + ' regions - ' + str(data['percent']) + '% coverage')"

function generate_fuzzer_corpus {

  proj_name=$1
  fuzz_time=$2
  fuzzer=$3
  proj_corpus=$4
  fuzzer_basename=$(basename $fuzzer)
  fuzzer_corpus="${fuzzer_basename}_corpus"

  mkdir $fuzzer_corpus
  timeout ${fuzz_time}s $fuzzer $fuzzer_corpus $proj_corpus
  sudo mkdir ./build/corpus/${proj_name}/${fuzzer_basename}
  sudo find $fuzzer_corpus/ -type f -name "*" -exec mv \
      --target-directory=./build/corpus/${proj_name}/${fuzzer_basename} {} +
  sudo rm -rf $fuzzer_corpus

}

function generate_report {

  yes | sudo python3 infra/helper.py build_image $proj_name
  sudo python3 infra/helper.py build_fuzzers $proj_name
  [ ! -d "./build/corpus/" ] && sudo mkdir ./build/corpus/
  [ ! -d "./build/corpus/${proj_name}/" ] \
      && sudo mkdir ./build/corpus/${proj_name}/

  echo "Running fuzzers..."
  find ./build/out/${proj_name}/ -maxdepth 1 -type f ! -name "*.*" \
      | parallel generate_fuzzer_corpus $proj_name $fuzz_time {} $proj_corpus

  sudo python3 infra/helper.py build_fuzzers --sanitizer=coverage $proj_name
  sudo python3 infra/helper.py coverage --port "" --no-corpus-download $proj_name
  cp ./build/out/${proj_name}/report/linux/summary.json \
      "$out_dir/${proj_name}_summary_${1}.json"
  python $py_format_filepath \
      ./build/out/${proj_name}/report/linux/summary.json $1 >> $out_file

}

export -f generate_fuzzer_corpus
git clone https://github.com/google/oss-fuzz
pushd oss-fuzz > $null_out
git checkout docker_port
generate_report original
popd > $null_out
generate_report modified
sudo rm -rf oss-fuzz
sudo rm -f format.py
echo -e "\n$proj_name coverage"
cat $out_file
popd > $null_out
