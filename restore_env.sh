backup_path="/mnt/ramdisk/"
restore_path="" # Should be the root directory (empty string ""). Can be changed to something else for testing
temp_dir="temp"
# Grab the list of files to be restored
includes="restore_includes.txt"
toRestores=()
read -a toRestores -d EOF < $includes

POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    -b|--backup-path)
      backup_path="$2"
      shift # past argument
      shift # past value
      ;;
    -r|--restore-path)
      restore_path="$2"
      shift # past argument
      shift # past value
      ;;
    -t|--temp-dir)
      temp_dir="$2"
      shift # past argument
      shift # past value
      ;;
    -i|--includes)
      includes="$2"
      shift # past argument
      shift # past value
      ;;
    -*|--*)
      echo "Unknown option $1"
      exit 1
      ;;
    *)
      POSITIONAL_ARGS+=("$1") # save positional arg
      shift # past argument
      ;;
  esac
done

set -- "${POSITIONAL_ARGS[@]}" # restore positional parameters
echo "**********************************"
echo "backup_path  = ${backup_path}"
echo "restore_path = ${restore_path}"
echo "temp_dir     = ${temp_dir}"
echo "includes txt = ${includes}"
echo "**********************************"
# First, check if the paths exist
checkIfPathExists() {
    if [ ! -d "$1" ]; then
        echo "Error: Path $1 does not exist."
        exit 42
    fi
}
checkIfPathExists $restore_path
checkIfPathExists $backup_path

# Uncompress the zip
cd $backup_path
mkdir -p $temp_dir
tar -xvf *.tar.gz --directory $temp_dir
cd $temp_dir
ls *.tar | xargs -n1 tar -xvf

# Restore files
for toRestore in "${toRestores[@]}"
do
  echo "Restoring $toRestore..."
#   find . -name "$backup_path$toRestore" -exec cp {} "$(dirname $restore_path$toRestore)" \;
  cp -Rpv "$backup_path/$temp_dir$toRestore" "$restore_path$toRestore"
done