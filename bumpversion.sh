set -e
[ -n "$(git status -s)" ] && echo "There are uncommitted changes" && exit

args=$1

[ -n "$2" ] && echo No second argument allowed && exit

# Extract current version
OLDVERSIONv=$(grep "^VERSION=" .env | cut -d'=' -f2)
OLDVERSION=${OLDVERSIONv#v}
major=$(echo $OLDVERSION | cut -d'.' -f1)
minor=$(echo $OLDVERSION | cut -d'.' -f2)
patch=$(echo $OLDVERSION | cut -d'.' -f3)

if [ "$args" = "major" ]
then
    newmajor=$(( major + 1))
    NEWVERSION="$newmajor.0.0"
elif [ "$args" = "minor" ]
then
    newminor=$(( minor + 1))
    NEWVERSION="$major.$newminor.0"
elif [ "$args" = "patch" ]
then
    newpatch=$(( patch + 1))
    NEWVERSION="$major.$minor.$newpatch"
elif [ "$args" = "undo" ]
then
    last_message=$(git log -1 --pretty=%B)
    [[ ! $last_message =~ ^Bumpversion ]] && echo "You've moved beyond Bumpversion. Can't undo." && exit
    git reset --hard HEAD^ && git tag -d v$OLDVERSION 
    exit
else
    echo 'Unknown $1' && exit
fi

# Check if OLDVERSION is found in the various files and bump version
for f in .env README.md src/my_package/__init__.py pyproject.toml
do
    [ ! grep -q "$OLDVERSION" $f ] && echo "$OLDVERSION not found in $f" && exit
    sed -i "s/$OLDVERSION/$NEWVERSION/g" $f
done

# Append to CHANGELOG.md
echo "# v$NEWVERSION" >> CHANGELOG.md
echo >> CHANGELOG.md
git log --pretty=oneline v${OLDVERSION}.. | \
    cut -d' ' -f2- | \
    sed '/^Merge/d' | \
    sed 's/_/\\_/g' | \
    awk '{print "- "$0}' | \
    tac >> CHANGELOG.md
echo >> CHANGELOG.md

# git add and commit and tag
[ "$NOCOMMIT" = "1" ] && exit
git add .  
git commit -m "Bumpversion: v$NEWVERSION" && git tag v$NEWVERSION

