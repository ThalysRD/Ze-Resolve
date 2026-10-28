"""Documentos disponíveis no aplicativo e por URL, com versão de aceite."""

from html import escape
import os

from fastapi import HTTPException
from fastapi.responses import HTMLResponse
from .schemas import DocumentOut

VERSION = "2026-10-25"
PRIVACY = """O Zé Resolve conecta clientes e prestadores de serviços locais.
Dados utilizados: identificação e contato, sessão de acesso, endereço do serviço, base de atendimento do prestador, pedidos, avaliações, mensagens e token do aparelho para notificações.
A localização do cliente é solicitada durante a busca, com alternativa por cidade. Não há rastreamento contínuo. A base exata do prestador é privada; o catálogo mostra distância aproximada em linha reta.
O catálogo publica nome profissional, categoria, cidade, descrição, preço da visita e avaliações. Endereço e conversa do serviço são acessíveis aos participantes. A descrição pública não deve conter documentos ou dados pessoais desnecessários.
Senhas são armazenadas como hash. Campos privados recuperáveis são cifrados. Firebase Cloud Messaging entrega notificações e o serviço de email configurado entrega códigos de acesso; eles não recebem o texto privado das conversas como conteúdo de push.
Você pode corrigir dados, revogar sessões e solicitar encerramento em Meu perfil → Segurança da conta ou pela página /account/closure. O encerramento remove os dados pessoais mantidos nos campos de sua conta, endereços, conteúdo de mensagens de sua autoria e solicitações que criou, e desativa o perfil e dispositivos. Identificadores, horários, preço acordado, notas e estados ficam como histórico operacional sem sua identificação nesses campos. Textos escritos por terceiros e cópias de segurança exigem o procedimento de atendimento do responsável; não prometemos eliminar menções indiretas automaticamente.
Backups precisam de acesso restrito e prazo de retenção publicado pelo responsável antes da operação comercial. Solicitações de acesso, correção ou tratamento de dados podem ser encaminhadas ao contato abaixo.
Este documento descreve o comportamento implementado. A equipe responsável deve revisar sua identificação, base legal, fornecedores e prazos de retenção antes da publicação comercial."""
TERMS = """O Zé Resolve organiza a descoberta e o agendamento de serviços entre clientes e profissionais independentes.
O profissional define um valor fixo da visita e publica horários. O valor da visita não é necessariamente o preço total do reparo; escopo, materiais e preços adicionais devem ser combinados antes da execução.
A escolha de um horário cria uma solicitação pendente, que precisa ser aceita. Novos pedidos aguardam resposta por até 30 minutos por padrão, limitado ao início da vaga; a política do ambiente pode configurar esse prazo. O prazo efetivo aparece no pedido. Há limite de cinco solicitações pendentes por cliente.
Recusa, cancelamento ou expiração liberam a vaga futura. O prestador informa um motivo ao cancelar depois de aceitar. Não há promessa de atendimento imediato, deslocamento calculado, pagamento ou qualificação técnica garantida pela plataforma.
Use dados verdadeiros e mantenha contato acessível. Não bloqueie agendas de forma abusiva, envie spam, exponha dados de terceiros ou utilize mensagens para assédio. O acesso pode ser suspenso mediante procedimento registrado.
As partes respondem pelas informações e pelos compromissos que assumem. Problemas de atendimento e solicitações sobre a conta devem ser encaminhados ao responsável pelo aplicativo, no contato abaixo. Direitos obrigatórios aplicáveis não são afastados por estes termos."""


def document(kind):
    if kind not in {"privacy", "terms"}:
        raise HTTPException(404, "Documento não encontrado.")
    return {
        "version": VERSION,
        "title": "Política de Privacidade" if kind == "privacy" else "Termos de Uso",
        "body": PRIVACY if kind == "privacy" else TERMS,
        "contact": os.getenv(
            "APP_CONTACT_EMAIL",
            "Responsável pelo Projeto Integrador — informe o canal de atendimento antes da publicação.",
        ),
    }


def register_policies(app):
    @app.get(
        "/legal/documents/{kind}",
        tags=["Documentos"],
        response_model=DocumentOut,
        summary="Consultar documento e versão de aceite",
        description="Pública. `kind` aceita `terms` (Termos de Uso) ou `privacy` (Política de Privacidade) e retorna título, texto, versão e contato. Outro valor retorna 404.",
    )
    def legal_document(kind: str):
        return document(kind)

    @app.get("/legal/{kind}", response_class=HTMLResponse, include_in_schema=False)
    def legal_page(kind: str):
        item = document(kind)
        paragraphs = "".join(
            f"<p>{escape(line)}</p>" for line in item["body"].splitlines()
        )
        return HTMLResponse(
            f'<!doctype html><html lang="pt-BR"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>{escape(item["title"])}</title><main style="max-width:48rem;margin:2rem auto;padding:1rem;font:1rem/1.6 sans-serif"><h1>{escape(item["title"])}</h1><p>Versão {VERSION}</p>{paragraphs}<p>Contato: {escape(item["contact"])}</p></main></html>'
        )
