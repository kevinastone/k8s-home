#!/usr/bin/env nu

const GITHUB_KNOWN_HOSTS = "github.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg="

const BOOTSTRAP_RELEASES = [
    {namespace: "prometheus", path: "crds/prometheus/helmrelease.yaml"}
    {namespace: "kube-system", path: "system/cilium/helmrelease.yaml"}
    {namespace: "flux-system", path: "crds/flux-operator/helmrelease.yaml"}
    {namespace: "flux-system", path: "system/fluxcd/helmrelease.yaml"}
]

# Bootstrap a bare kubeadm cluster with Cilium, secrets from 1Password, and FluxCD.
def main [
    --yes (-y) # Skip interactive confirmation prompt
    --dry-run (-d) # Validate prerequisites and preview actions without modifying the cluster
    --repo-root (-r): path = "." # Path to the k8s-home repository root
] {
    let root = $repo_root | path expand

    print (banner "Pre-flight Checks")
    preflight_check $root

    let context = kubectl config current-context | str trim
    print $"Target Kubernetes context: (style $context 'cyan')"
    print ""
    kubectl get nodes -o wide
    print ""

    print "Bootstrap releases:"
    for rel in $BOOTSTRAP_RELEASES {
        let hr = open ($root | path join $rel.path)
        print $"  - ($rel.namespace)/($hr.metadata.name) \(($hr.spec.chart.spec.url):($hr.spec.chart.spec.ref.tag)\)"
    }
    print ""

    if not $yes and not $dry_run {
        let answer = (
            input "Proceed with cluster bootstrap? [y/N]: "
            | str trim
            | str lowercase
        )
        if $answer not-in ["y" "yes"] {
            print "Aborted."
            exit 0
        }
    }

    print (banner "1/4 Creating Core Namespaces")
    for ns in ["flux-system" "prometheus"] {
        ensure_namespace $ns --dry-run=$dry_run
    }

    print (banner "2/4 Injecting Bootstrap Secrets from 1Password")
    apply_bootstrap_secrets --dry-run=$dry_run

    print (banner "3/4 Installing Core HelmReleases")
    let prometheus_rel = $BOOTSTRAP_RELEASES.0
    apply_helmrelease ($root | path join $prometheus_rel.path) --namespace $prometheus_rel.namespace --dry-run=$dry_run

    let cilium_rel = $BOOTSTRAP_RELEASES.1
    apply_helmrelease ($root | path join $cilium_rel.path) --namespace $cilium_rel.namespace --dry-run=$dry_run

    if not $dry_run {
        print "==> Waiting for all nodes to become Ready..."
        kubectl wait --for=condition=Ready nodes --all --timeout=120s
    }

    let flux_op_rel = $BOOTSTRAP_RELEASES.2
    apply_helmrelease ($root | path join $flux_op_rel.path) --namespace $flux_op_rel.namespace --dry-run=$dry_run

    let flux_rel = $BOOTSTRAP_RELEASES.3
    apply_helmrelease ($root | path join $flux_rel.path) --namespace $flux_rel.namespace --dry-run=$dry_run

    print (banner "4/4 Verifying FluxCD Bootstrap")
    if $dry_run {
        print "[dry-run] Skipping post-bootstrap verification."
        return
    }

    print "==> Waiting for GitRepository/fluxcd-sync..."
    kubectl wait --namespace flux-system --for=condition=Ready gitrepository/fluxcd-sync --timeout=120s

    print ""
    flux get kustomizations
    print ""
    print (style "Bootstrap complete!" "green")
    print "Watch reconciliation progress with: flux get kustomizations --watch"
}

def preflight_check [root: path] {
    for rel in $BOOTSTRAP_RELEASES {
        let full_path = $root | path join $rel.path
        if not ($full_path | path exists) {
            print -e $"Error: Missing HelmRelease manifest '($full_path)'. Run from the k8s-home repo root or pass --repo-root."
            exit 1
        }
    }

    let k8s = kubectl cluster-info o+e>| complete
    if $k8s.exit_code != 0 {
        print -e "Error: Unable to connect to Kubernetes cluster. Check KUBECONFIG."
        print -e $k8s.stdout
        exit 1
    }

    if (which op | is-empty) {
        print -e "Error: 1Password CLI ('op') not found on PATH. Install it (e.g. 'brew install 1password-cli') and try again."
        exit 1
    }

    try {
        op whoami
    } catch {
        print "==> Signing in to 1Password CLI..."
        op signin
    }
}

def ensure_namespace [ns: string, --dry-run] {
    print $"==> Ensuring namespace ($ns)..."
    if $dry_run {
        kubectl create namespace $ns --dry-run=client -o yaml | ignore
        print $"  [dry-run] Would apply namespace ($ns)"
        return
    }

    kubectl create namespace $ns --dry-run=client -o yaml
    | kubectl apply --server-side -f -
}

def apply_bootstrap_secrets [--dry-run] {
    print "==> Reading sops-age and fluxcd-sync secrets from 1Password..."
    let age_key = op read "op://Homelab/age.agekey/credential" | str trim
    let ssh_private = (
        op read "op://Homelab/FluxCD Deploy Key/private key?ssh-format=openssh"
        | str trim
    )
    let ssh_public = op read "op://Homelab/FluxCD Deploy Key/public key" | str trim

    apply_secret "sops-age" {"age.agekey": $age_key} --namespace "flux-system" --dry-run=$dry_run

    apply_secret "fluxcd-sync" {
        identity: $ssh_private
        "identity.pub": $ssh_public
        known_hosts: $GITHUB_KNOWN_HOSTS
    } --namespace "flux-system" --dry-run=$dry_run
}

def apply_secret [
    name: string
    string_data: record
    --namespace(-n): string = "flux-system"
    --dry-run
] {
    print $"==> Applying Secret ($namespace)/($name)..."
    if $dry_run {
        print $"  [dry-run] Would apply Secret ($namespace)/($name)"
        return
    }

    {
        apiVersion: "v1"
        kind: "Secret"
        metadata: {name: $name, namespace: $namespace}
        stringData: $string_data
    }
    | to yaml
    | kubectl apply --server-side -f -
}

def apply_helmrelease [manifest: path, --namespace(-n): string, --dry-run] {
    let hr = open $manifest
    let name = $hr.metadata.name
    let chart = $hr.spec.chart.spec.url
    let version = $hr.spec.chart.spec.ref.tag
    let values = $hr.spec.values? | default {}

    print $"==> Installing HelmRelease ($namespace)/($name) \(($chart):($version)\)..."

    if $dry_run {
        $values
        | to yaml
        | helm upgrade --install $name $chart --namespace $namespace --create-namespace --version $version --values - --reset-values --force-conflicts --dry-run
        | ignore
        print $"  [dry-run] Validated ($namespace)/($name)"
    } else {
        $values
        | to yaml
        | helm upgrade --install $name $chart --namespace $namespace --create-namespace --version $version --values - --reset-values --force-conflicts --wait --wait-for-jobs
    }
}

def banner [title: string] {
    $"\n(style $'=== ($title) ===' 'blue')"
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
