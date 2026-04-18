# Guia rápido — identidade visual (Flutter)

**Objetivo:** manter novas telas consistentes com a dashboard e com o resto do app.

---

## Princípios

1. **Fundo:** gradiente suave de `AppColors.lightBlue` para branco (não usar cinza plano como fundo principal de ecrã).
2. **Hierarquia de texto:** títulos de ecrã → `headlineLarge` ou `headlineMedium`; secções → `titleLarge`; corpo → `bodyLarge` / `bodyMedium` do tema.
3. **Ações primárias:** botão laranja (`AppButton` padrão); ações secundárias com contorno azul (`AppButtonType.secondary`).
4. **Superfícies:** cartões brancos com cantos ~16px (`AppCard`); “folhas” sobre o gradiente com `AppDecor.whiteTopSheet()` quando fizer sentido (lista sobre fundo branco arredondado no topo).

---

## O que importar

```dart
import '../theme/app_theme.dart';
import '../widgets/app_screen_chrome.dart';
```

---

## Padrão com AppBar

```dart
Scaffold(
  appBar: AppScreenChrome.appBar(
    context,
    title: 'Título do ecrã',
    actions: [ /* IconButtons com AppColors.primaryBlue */ ],
  ),
  body: AppGradientBackground(
    child: /* SafeArea opcional */ seuConteúdo,
  ),
);
```

---

## Padrão sem AppBar (cabeçalho manual)

Igual à home: `Container` com `BoxDecoration(gradient: AppGradients.screenBackground)` + `SafeArea` + `padding: AppLayout.screenPadding`.

---

## Constantes úteis

| Nome | Descrição |
|------|-----------|
| `AppGradients.screenBackground` | `LinearGradient` oficial |
| `AppLayout.screenPadding` | `EdgeInsets.fromLTRB(24, 16, 24, 24)` |
| `AppLayout.screenPaddingSymmetricH` | só horizontal 24 |
| `AppDecor.whiteTopSheet({double radius})` | painel branco superior arredondado |

---

## Cores (`AppColors`)

- `primaryBlue` — marca, títulos, ícones principais  
- `accentOrange` — CTA, destaques, indicadores de tabs  
- `lightBlue` — faixa do AppBar e topo do gradiente  
- `errorRed` — erros e eliminação  

---

*Para o estado completo do produto, ver `DOCUMENTACAO_ATUAL.md` e `ENTREGAS_E_PENDENCIAS.md`.*
