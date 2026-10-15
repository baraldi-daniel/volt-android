# VOLT — Android (Godot 4.4.1)

Este é um **protótipo experimental** e não um jogo comercial. Inclui cenário procedural, herói estilizado, gangues, combate, veículos terrestres simples e 20 chefões sequenciais com progressão numérica. Não inclui avião/trem jogáveis, modelos 3D profissionais nem habilidades únicas por chefão.

## Gerar APK sem instalar Godot (GitHub Actions)

1. Crie um repositório **vazio** no GitHub (ex.: `volt-android`).
2. Descompacte este ZIP no celular. Na página do repositório, use **Add file → Upload files** (talvez seja necessário abrir a versão para computador do navegador) e envie o **conteúdo** da pasta `VOLT_Godot`, mantendo `main.gd`, `main.tscn`, `project.godot`, `export_presets.cfg` e `.github/workflows/android.yml` nos caminhos indicados. Arquivos da pasta `.github` podem estar ocultos no gerenciador de arquivos.
3. Faça **Commit changes** na branch `main`.
4. Abra **Actions → Gerar APK Android → Run workflow** (ou aguarde a execução automática pelo push).
5. Quando a execução ficar verde, abra a execução e baixe o artefato **VOLT-Android-APK**. Extraia o ZIP do artefato e toque em `VOLT-debug.apk` para instalar.
6. Se o Android pedir, autorize **Instalar apps desconhecidos** para o app que abriu o APK.

**Importante:** esta pipeline ainda não foi executada/validada nesta sessão. Se falhar, compartilhe a tela do erro do GitHub Actions para corrigirmos. APK debug é para testes, não distribuição em loja. Não é necessário inserir senhas ou tokens do GitHub aqui.
