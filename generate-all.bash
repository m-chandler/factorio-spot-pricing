TEMPLATE_DIR="${PWD}/templates"

bash factorio-script.bash ${i} > "${TEMPLATE_DIR}/1-server/update-factorio-servers.bash"

for i in 5 10 15 20 40 60
do
  echo "Generating $i..."
  SERVER_DIR="${TEMPLATE_DIR}/${i}-servers"
  echo "Generating to ${SERVER_DIR}"
  mkdir -p "${SERVER_DIR}"
  bash src/parameterised.bash ${i} > "${SERVER_DIR}/cf.yml"
  bash src/factorio-script.bash ${i} > "${SERVER_DIR}/update-factorio-servers.bash"
  echo "Generated $i!"
done