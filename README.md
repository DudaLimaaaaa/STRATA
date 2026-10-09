# STRATA — Demo 01: A primeira descoberta

Protótipo greybox jogável de aventura 2D, inspirado na Patagônia austral. O objetivo é localizar e registrar o Amonite Dourado; a descoberta é fictícia e permanece no afloramento.

## Executar

1. Instale/abra Godot 4.5 ou compatível com Godot 4.x.
2. Importe este diretório como projeto existente.
3. Pressione **F6/F5** ou abra `scenes/main.tscn`.

O projeto usa apenas formas e cores geradas por código. Não há assets externos nem necessidade de rede.

## Controles

| Ação | Teclas |
| --- | --- |
| Mover | A/D ou setas |
| Correr | Shift |
| Saltar | Espaço |
| Interagir | E |
| GeoAtlas | Tab |
| Pausar | Esc |

## Conteúdo desta rodada

- Fase contínua P1–P5, com rota baixa e rota alta opcional que convergem no corredor final.
- Controle responsivo com corrida, coyote time e jump buffer.
- Estação, checkpoint, aviso/perigo de queda, mirante registrável e Amonite Dourado.
- GeoAtlas simples que pausa a física e só mostra registros descobertos.
- Menu, pausa, reinício e tela de conclusão.

## Limites conhecidos

Esta é uma primeira greybox: não há arte ou áudio finais, menu de configurações, build exportada ou playtest. A geometria, o alcance dos saltos, o ritmo do perigo e as colisões precisam ser calibrados com o controlador dentro do Godot antes de expandir conteúdo.

O cenário é fictício e estilizado. Río Turbio informa o contexto visual regional, sem afirmar que a ocorrência do amonite represente uma unidade fossilífera real específica.

