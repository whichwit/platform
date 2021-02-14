"""Test rule that fails if a source file has too long lines."""

def _check_file(f):
    """Return shell commands for testing file 'f'."""

    # We write information to stdout. It will show up in logs, so that the user
    # knows what happened if the test fails.
    return """
echo Testing that {file} contains valid T-SQL scripts...
echo "SET PARSEONLY ON;" > {path}_parse
cat {path} >> {path}_parse
cat {path}_parse
sqlcmd -S localhost -U sa -P Password1! -i {path}_parse
""".format(path = f.path, file = f.short_path)

def _impl(ctx):
    script = "\n".join(
        ['echo $TEST_TMPDIR'] +
        [_check_file(f) for f in ctx.files.srcs]
    )

    # for f in ctx.files.srcs
    # ctx.actions.write(
    #     output =
    # )

    # Write the file, it is executed by 'bazel test'.
    ctx.actions.write(
        output = ctx.outputs.executable,
        content = script,
    )

    # To ensure the files needed by the script are available, we put them in
    # the runfiles.
    runfiles = ctx.runfiles(files = ctx.files.srcs)
    return [DefaultInfo(runfiles = runfiles)]

parse_sql_test = rule(
    implementation = _impl,
    attrs = {
        "srcs": attr.label_list(allow_files = True),
    },
    test = True,
)
