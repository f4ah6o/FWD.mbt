bootstrap:
    moon run src/cli -- validate src/schema/fwd_schema.yaml
    moon run src/cli -- src/schema/fwd_schema.yaml /tmp/fwd_schema.ir.json
    diff -u src/schema/fwd_schema.ir.json /tmp/fwd_schema.ir.json

ci:
    bash scripts/ci.sh

workbench-shadow-ci:
    moon check --target all src/workbench_v6 src/ui/workbench_v6 src/api_v6
    moon build src/ui/client/main --target js
    moon run src/workbench_shadow_ci
    just ci

tornado *args:
    opz z.ai -- tornado --config=tornado.json {{args}}

tornado-validate:
    opz z.ai -- tornado validate tornado.json
