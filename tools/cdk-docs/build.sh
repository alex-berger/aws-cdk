#!/bin/bash
set -euo pipefail
scriptdir=$(cd $(dirname $0) && pwd)

#----------------------------------------------------------------------

full=false
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--full)
            full=true
            ;;
        -h|--help)
            echo "Usage: build.sh [--full|-f]" >&2
            exit 1
            ;;
        *)
            echo "Unrecognized argument: $1" >&2
            exit 1
            ;;
    esac
    shift
done

#----------------------------------------------------------------------

outdir=$scriptdir/dist
mkdir -p $outdir

distdir=$scriptdir/../../dist
javadocdir=$outdir/reference/java
typescriptdir=$outdir/reference/typescript
dotnetdir=$outdir/reference/dotnet

args=""

build_failed() {
    if $full; then
        echo "ERROR: Build of $1 failed." >&2
        exit 1
    else
        printf '\e[1;34m%-6s\e[m\n' "Build of $1 failed. Skipping." >&2
    fi
}

$scriptdir/java/build-javadoc.sh $distdir/java $javadocdir && {
    args="$args --java /reference/java"
} || build_failed "JavaDocs"

$scriptdir/typescript/build-typescript.sh $distdir/js $typescriptdir && {
    args="$args --typescript /reference/typescript"
} || build_failed "TypeScript docs"

$scriptdir/dotnet/build-dotnet.sh $distdir/dotnet $dotnetdir && {
    args="$args --dotnet /reference/dotnet"
} || build_failed ".NET docs"

# Generate CDK reference
(
    cd gen-cdk-reference
    [[ -d node_modules ]] || npm install
    tsc
    npm run gen-cdk-reference -- $args \
        --website $scriptdir/docusaurus/website \
        --docs $scriptdir/docusaurus/docs
)

# Build website
if $full; then
    (
        cd docusaurus/website
        [[ -d node_modules ]] || npm install
        npm run build
        cp -R build/cdk-reference/* $outdir
    )
fi
