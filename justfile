bootstrap:
    moon run src/cli -- validate src/schema/fwd_schema.yaml
    moon run src/cli -- src/schema/fwd_schema.yaml /tmp/fwd_schema.ir.json
    diff -u src/schema/fwd_schema.ir.json /tmp/fwd_schema.ir.json

ci:
    moon check
    moon test
    just bootstrap
