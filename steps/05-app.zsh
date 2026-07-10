# Phase 5: install the runtime launcher and ProxyGPT.app bundle.

proxygpt_step_app() {
  proxygpt_install_app_bundle || return 1
  proxygpt_register_app_bundle || return 1
  proxygpt_success "App phase completed"
}
