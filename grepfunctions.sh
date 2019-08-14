# Functions to extend grep

# Extend grep to perform a useful search for development
grepx() {
  MATCH="$@"
  var=0

  grep -lrai \
  --exclude-dir={.metadata,.jazz5,.jazzShed,.git,.mule,target,bin,*Documentation,RoboHelp*} \
  --exclude={*.jar,*.class,*.zip,*.sql,*.doc,*.docx,*.ppt,*.pptx,*.xls,*.xlsx,*.png,*.jpg,*.gif,*.Png,*.pdf,*.mp4,*.exe,*.msi,*.7z} \
  "$MATCH" ./ | while read file
  do
      echo
      let "var=var+1"
      echo "Hit $var"
      echo -e "\e[35m${file}"
      grep --color=always -nhai -A10 -B10 "$MATCH" "${file}"
  done
}

# Extend grep to perform a useful search for development - but only displays the file name
grepx_x_filename() {
  MATCH="$@"

  grep -lrai \
  --exclude-dir={.metadata,.jazz5,.jazzShed,.git,.mule,target,bin,*Documentation,RoboHelp*} \
  --exclude={*.jar,*.class,*.zip,*.sql,*.doc,*.docx,*.ppt,*.pptx,*.xls,*.xlsx,*.png,*.jpg,*.gif,*.Png,*.pdf,*.mp4,*.exe,*.msi,*.7z} \
  "$MATCH" ./ | while read file
  do
      echo -e "\e[35m${file}"
  done
}

# Search inside code
grepx_codescan() {
  MATCH="$@"
  var=0

  grep -lrai \
  --exclude-dir={.metadata,.jazz5,.git,bin} \
  --exclude={*.jar,*.class,*.zip} \
  "$MATCH" ./ | while read file
  do
      echo
      let "var=var+1"
      echo "Hit $var"
      echo -e "\e[35m${file}"
      grep --color=always -nhai -A5 -B5 "$MATCH" "${file}"
  done
}

# Search for Android projects
grepx_android() {
  MATCH="$@"
  var=0

  grep -lrai \
  --exclude-dir={.gradle,.idea,.git,gradle,build} \
  --exclude={*.jar,*.class,*.zip,*.apk,*.iml,gradlew,*.png,*.jpg,*.gif,*.Png,*.pdf,*.mp4,*.exe,*.msi,*.7z} \
  "$MATCH" ./ | while read file
  do
      echo
      let "var=var+1"
      echo "Hit $var"
      echo -e "\e[35m${file}"
      grep --color=always -nhai -A5 -B5 "$MATCH" "${file}"
  done
}

# Only search code files (including xml files for spring configs)
grepx_code() {
  MATCH="$@"
  var=0

  grep -lrai \
  --exclude-dir={.metadata,.jazz5,.git,.mule,target,bin,*Documentation,RoboHelp*} \
  --exclude={*.jar,*.class,*.zip,*.properties,*.sql,*.jsp,*.xhtml,*.html,*.htm,*.doc,*.docx,*.ppt,*.pptx,*.xls,*.xlsx,*.png,*.jpg,*.gif,*.Png,*.pdf,*.mp4,*.exe,*.msi,*.7z} \
  "$MATCH" ./ | while read file
  do
      echo
      let "var=var+1"
      echo "Hit $var"
      echo -e "\e[35m${file}"
      grep --color=always -nhai -A5 -B5 "$MATCH" "${file}"
  done
}

# Only search web files
grepx_web() {
  MATCH="$@"
  var=0

  grep -lrai \
  --exclude-dir={.metadata,.jazz5,.git,.mule,target,bin,*Documentation,RoboHelp*} \
  --exclude={*.jar,*.class,*.zip,*.properties,*.sql,*.java,*.xml,*.doc,*.docx,*.ppt,*.pptx,*.xls,*.xlsx,*.png,*.jpg,*.gif,*.Png,*.pdf,*.mp4,*.exe,*.msi,*.7z} \
  "$MATCH" ./ | while read file
  do
      echo
      let "var=var+1"
      echo "Hit $var"
      echo -e "\e[35m${file}"
      grep --color=always -nhai -A5 -B5 "$MATCH" "${file}"
  done
}

# Only search java files
grepx_java() {
  MATCH="$@"
  var=0

  grep -lrai \
  --exclude-dir={.metadata,.jazz5,.git,.mule,target,bin,*Documentation,RoboHelp*} \
  --include=*.java \
  "$MATCH" ./ | while read file
  do
      echo
      let "var=var+1"
      echo "Hit $var"
      echo -e "\e[35m${file}"
      grep --color=always -nhai -A5 -B5 "$MATCH" "${file}"
  done
}

# Only search java files - but only displays the file name
grepx_java_filename() {
  MATCH="$@"
  var=0

  grep -lrai \
  --exclude-dir={.metadata,.jazz5,.git,.mule,target,bin,*Documentation,RoboHelp*} \
  --include=*.java \
  "$MATCH" ./ | while read file
  do
      echo -e "\e[35m${file}"
  done
}

# Only search javascript files
grepx_javascript() {
  MATCH="$@"
  var=0

  grep -lrai \
  --exclude-dir={.metadata,.jazz5,.git,.mule,target,bin,*Documentation,RoboHelp*} \
  --include=*.js \
  "$MATCH" ./ | while read file
  do
      echo
      let "var=var+1"
      echo "Hit $var"
      echo -e "\e[35m${file}"
      grep --color=always -nhai -A5 -B5 "$MATCH" "${file}"
  done
}

# Only search xhtml files
grepx_xhtml() {
  MATCH="$@"
  var=0

  grep -lrai \
  --exclude-dir={.metadata,.jazz5,.git,.mule,target,bin,*Documentation,RoboHelp*} \
  --include=*.xhtml \
  "$MATCH" ./ | while read file
  do
      echo
      let "var=var+1"
      echo "Hit $var"
      echo -e "\e[35m${file}"
      grep --color=always -nhai -A5 -B5 "$MATCH" "${file}"
  done
}

# Only search css files
grepx_css() {
  MATCH="$@"
  var=0

  grep -lrai \
  --exclude-dir={.metadata,.jazz5,.git,.mule,target,bin,*Documentation,RoboHelp*} \
  --include=*.css \
  "$MATCH" ./ | while read file
  do
      echo
      let "var=var+1"
      echo "Hit $var"
      echo -e "\e[35m${file}"
      grep --color=always -nhai -A5 -B5 "$MATCH" "${file}"
  done
}


# Only search sql
grepx_sql() {
  MATCH="$@"
  var=0

  grep -lrai \
  --exclude-dir={.metadata,.jazz5,.git,.mule,target,bin,*Documentation,RoboHelp*} \
  --include=*.sql \
  "$MATCH" ./ | while read file
  do
      echo
      let "var=var+1"
      echo "Hit $var"
      echo -e "\e[35m${file}"
      grep --color=always -nhai -A5 -B5 "$MATCH" "${file}"
  done
}

# Only search xml
grepx_xml() {
  MATCH="$@"
  var=0

  grep -lrai \
  --exclude-dir={.metadata,.jazz5,.git,.mule,target,bin,*Documentation,RoboHelp*} \
  --include=*.xml \
  "$MATCH" ./ | while read file
  do
      echo
      let "var=var+1"
      echo "Hit $var"
      echo -e "\e[35m${file}"
      grep --color=always -nhai -A5 -B5 "$MATCH" "${file}"
  done
}

# Only search for documentation by file name
grepx_docs() {
  MATCH="$@"

  find . \
  -not \( -path "*/.git*" -prune \) \
  -not \( -path "*/.metadata*" -prune \) \
  -not \( -path "*/.mule*" -prune \) \
  -not \( -path "*/.idea*" -prune \) \
  -not \( -path "*/bin*" -prune \) \
  -not \( -path "*/target*" -prune \) \
  -not \( -path "*/.metadata*" -prune \) \
  -not \( -path "*/.jazz5*" -prune \) \
  -not \( -path "*/bin*" -prune \) \
  \( -iname "*.doc*" -o -iname "*.pdf" -o -iname "*.ppt*" -o -iname "*.xls*" \) \
  -iname "*$MATCH*" | while read file
  do
    echo -e "\e[35m${file}"
  done
}

# Only search by file name
grepx_filename() {
  MATCH="$@"

  find . \
  -not \( -path "*/.git*" -prune \) \
  -not \( -path "*/.metadata*" -prune \) \
  -not \( -path "*/.jazz5*" -prune \) \
  -not \( -path "*/bin*" -prune \) \
  -not \( -path "*/target*" -prune \) \
  -not \( -path "*/.mule*" -prune \) \
  -not \( -path "*/.idea*" -prune \) \
  -not \( -path "*/*Documentation*" -prune \) \
  -not \( -path "*/RoboHelp*" -prune \) \
  \( -not -iname "*.class" -and -not -iname "*.properties" -and -not -iname "*.sql" \
  -not -iname "*.doc*" -and -not -iname "*.pdf" -and -not -iname "*.ppt*" -and -not -iname "*.xls*" -and -not -iname "*.zip" \) \
  -iname "*$MATCH*" | while read file
  do
    echo -e "\e[35m${file}"
  done
}

# Only search for jars by file name
grepx_jar() {
  MATCH="$@"

  find . \
  -not \( -path "*/.git*" -prune \) \
  -not \( -path "*/.metadata*" -prune \) \
  -not \( -path "*/.jazz5*" -prune \) \
  -not \( -path "*/bin*" -prune \) \
  -not \( -path "*/*Documentation*" -prune \) \
  -not \( -path "*/RoboHelp*" -prune \) \
  \( -iname "*.jar" \) \
  -iname "*$MATCH*" | while read file
  do
    echo -e "\e[35m${file}"
  done
}
