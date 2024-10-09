for i in 5 10 15 20 40 60
do
  echo "Generating $i..."
  SERVER_DIR="${PWD}/templates/${i}-servers"
  echo "Generating to ${SERVER_DIR}"
  mkdir -p "${SERVER_DIR}"
  bash parameterised.bash ${i} > "${SERVER_DIR}/cf.yml"
  echo "Generated $i!"
done