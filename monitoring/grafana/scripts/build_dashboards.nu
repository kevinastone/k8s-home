#!/usr/bin/env nu

# Build or validate Grafana CUE dashboards.
def main [
    target_dir: path = "." # Directory to search for dashboards (default: '.')
    --check(-c) # Validate dashboards against committed JSON without modifying files
    --verbose(-v) # Show verbose output for dashboards
] {
    if not ($target_dir | path exists) {
        print -e $"Error: Directory '($target_dir)' does not exist."
        exit 1
    }

    let target_root = $target_dir | path expand
    let module_root = if ($target_dir | path join "cue.mod" | path exists) {
        $target_dir
    } else {
        "."
    }

    let dashboards = find_dashboards $target_dir $target_root
    if ($dashboards | is-empty) {
        print $"No .cue files found in '($target_dir)'."
        return
    }

    print $"((if $check { "Checking" } else { "Building" })) CUE dashboards in '($target_dir)'"

    let handler = if $check {
        {|dash, cue|
            let existing = if ($dash.json | path exists) { $dash.json } else { "/dev/null" }
            $cue.stdout | diff --unified --label $dash.rel_json --label "(cue export)" $existing - o+e>| complete
        }
    } else {
        {|dash, cue|
            $cue.stdout | save --force $dash.json
            $cue
        }
    }

    let success = $dashboards | par-each {|dash|
        let cue = (
            cue --chdir $module_root export $dash.cue --expression out --out json
            o+e>| complete
        )
        let res = if $cue.exit_code == 0 {
            do $handler $dash $cue
        } else {
            $cue
        }
        let success = $res.exit_code == 0
        let icon = if $success {
            style "✓" "green"
        } else {
            style "✗" "red"
        }
        print $"  ($icon) ($dash.display_pair)"

        if $verbose {
            print -n $res.stdout
        }

        $success
    } | all {}

    if not $success {
        exit 1
    }

    print (if $check { "All dashboards are in sync." } else { "Done." })
}

def find_dashboards [target_dir: path, target_root: path] {
    let pattern = if ($target_dir | path basename) == "dashboards" {
        $"($target_dir)/*.cue"
    } else {
        $"($target_dir)/**/dashboards/*.cue"
    }

    glob $pattern --no-dir --exclude ["**/cue.mod/**" "**/.git/**"]
    | each {|cue|
        let parts = $cue | path parse
        let json = $parts | update extension "json" | path join
        let rel_parent = $parts.parent | path relative-to $target_root

        {
            cue: $cue
            json: $json
            rel_json: ($json | path relative-to $target_root)
            display_pair: ($rel_parent | path join $"\{($parts.stem).cue => ($parts.stem).json\}")
        }
    }
}

def style [text: string, color: string] {
    let disable_color = $env.NO_COLOR? | is-not-empty
    let force_color = (($env.CLICOLOR_FORCE? | default "0") != "0") or (($env.FORCE_COLOR? | default "0") != "0")
    let supports_color = (is-terminal --stdout) or $force_color

    if $supports_color and not $disable_color {
        $"(ansi $color)($text)(ansi reset)"
    } else {
        $text
    }
}
