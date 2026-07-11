# Этап 5: установка загрузчика среды выполнения и приложения .app.

proxygpt_step_app() {
  proxygpt_install_app_bundle || return 1
  proxygpt_register_app_bundle || return 1
  proxygpt_success "Этап приложения завершён"
}
