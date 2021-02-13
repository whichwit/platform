load("tools/create_or_alter_test.bzl", "create_or_alter_test")
load("tools/ends_with_go_test.bzl", "ends_with_go_test")


filegroup(
    name = "sqlscripts",
    srcs = glob(["src/**/*.sql"])
)

# Run 'bazel test :80columns' to check that all files in the directory
# have at most 80 columns.
create_or_alter_test(
    name = "create_or_alter_keyword",
    srcs = glob(["src/**/*.sql"]),
    timeout = "short",
)

ends_with_go_test(
    name = "ends_with_go_keyword",
    srcs = [":sqlscripts"],
    timeout = "short",
)