/* =====================================================================
   VICXMOURA PISCINAS – funções comuns do site e do painel
   Máscaras (telefone, CEP, CPF/CNPJ), validações e busca de endereço pelo CEP.
   ===================================================================== */
(function (global) {
  "use strict";
  const digitos = v => String(v ?? "").replace(/\D/g, "");

  function mascaraTel(v) {
    const d = digitos(v).slice(0, 11);
    if (d.length <= 2) return d.length ? "(" + d : "";
    if (d.length <= 6) return `(${d.slice(0, 2)}) ${d.slice(2)}`;
    if (d.length <= 10) return `(${d.slice(0, 2)}) ${d.slice(2, 6)}-${d.slice(6)}`;
    return `(${d.slice(0, 2)}) ${d.slice(2, 7)}-${d.slice(7)}`;
  }
  function mascaraCep(v) {
    const d = digitos(v).slice(0, 8);
    return d.length > 5 ? d.slice(0, 5) + "-" + d.slice(5) : d;
  }
  function mascaraDoc(v) {
    const d = digitos(v).slice(0, 14);
    if (d.length <= 11) {
      return d.replace(/^(\d{3})(\d)/, "$1.$2").replace(/^(\d{3})\.(\d{3})(\d)/, "$1.$2.$3").replace(/\.(\d{3})(\d{1,2})$/, ".$1-$2");
    }
    return d.replace(/^(\d{2})(\d)/, "$1.$2").replace(/^(\d{2})\.(\d{3})(\d)/, "$1.$2.$3")
            .replace(/\.(\d{3})(\d)/, ".$1/$2").replace(/(\d{4})(\d{1,2})$/, "$1-$2");
  }
  const MASCARAS = { tel: mascaraTel, cep: mascaraCep, doc: mascaraDoc };

  function telValido(v) { const d = digitos(v); return d.length === 10 || d.length === 11; }
  function cepValido(v) { return digitos(v).length === 8; }
  function emailValido(v) { return !v || /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(String(v).trim()); }
  function docValido(v) {
    const d = digitos(v);
    if (d.length === 11) {
      if (/^(\d)\1{10}$/.test(d)) return false;
      const calc = n => { let s = 0; for (let i = 0; i < n; i++) s += +d[i] * (n + 1 - i); const r = (s * 10) % 11; return r === 10 ? 0 : r; };
      return calc(9) === +d[9] && calc(10) === +d[10];
    }
    if (d.length === 14) {
      if (/^(\d)\1{13}$/.test(d)) return false;
      const calc = n => { const p = n === 12 ? [5,4,3,2,9,8,7,6,5,4,3,2] : [6,5,4,3,2,9,8,7,6,5,4,3,2];
        let s = 0; for (let i = 0; i < n; i++) s += +d[i] * p[i]; const r = s % 11; return r < 2 ? 0 : 11 - r; };
      return calc(12) === +d[12] && calc(13) === +d[13];
    }
    return false;
  }
  function tipoDoc(v) { const n = digitos(v).length; return n === 11 ? "CPF" : n === 14 ? "CNPJ" : ""; }

  // Busca o endereço no ViaCEP. Retorna {logradouro, bairro, cidade, uf} ou lança Error com mensagem amigável.
  async function buscarCep(cep) {
    const d = digitos(cep);
    if (d.length !== 8) throw new Error("CEP incompleto.");
    const ctrl = new AbortController(); const t = setTimeout(() => ctrl.abort(), 7000);
    let r;
    try { r = await fetch(`https://viacep.com.br/ws/${d}/json/`, { signal: ctrl.signal }); }
    catch (e) { throw new Error("Não foi possível buscar o CEP agora. Preencha o endereço manualmente."); }
    finally { clearTimeout(t); }
    if (!r.ok) throw new Error("Não foi possível buscar o CEP agora. Preencha o endereço manualmente.");
    const j = await r.json().catch(() => ({ erro: true }));
    if (j.erro) throw new Error("CEP não encontrado. Confira o número.");
    return { logradouro: j.logradouro || "", bairro: j.bairro || "", cidade: j.localidade || "", uf: j.uf || "" };
  }

  // Liga um campo de CEP aos campos de endereço: ao completar 8 dígitos, preenche o resto.
  // campos = {logradouro, bairro, cidade, uf, numero} (elementos), aviso = elemento para mensagens
  function ligarCep(input, campos, aviso, aoPreencher) {
    let ultimo = "";
    const msg = (t, erro) => { if (!aviso) return; aviso.textContent = t || ""; aviso.dataset.erro = erro ? "1" : ""; aviso.hidden = !t; };
    input.addEventListener("input", async () => {
      const d = digitos(input.value);
      if (d.length < 8) { msg(""); ultimo = ""; return; }
      if (d === ultimo) return; ultimo = d;
      msg("Buscando endereço…");
      try {
        const e = await buscarCep(d);
        if (digitos(input.value) !== d) return;
        if (campos.logradouro && e.logradouro) campos.logradouro.value = e.logradouro;
        if (campos.bairro && e.bairro) campos.bairro.value = e.bairro;
        if (campos.cidade) campos.cidade.value = e.cidade;
        if (campos.uf) campos.uf.value = e.uf;
        msg(e.logradouro ? "" : "CEP geral da cidade: preencha a rua.");
        if (campos.numero && !e.logradouro && campos.logradouro) campos.logradouro.focus();
        else if (campos.numero) campos.numero.focus();
        aoPreencher && aoPreencher(e);
      } catch (err) { msg(err.message, true); aoPreencher && aoPreencher(null, err); }
    });
  }

  // Aplica as máscaras em qualquer campo com data-mask="tel|cep|doc"
  function ligarMascaras(root) {
    (root || document).addEventListener("input", e => {
      const el = e.target, m = el && el.dataset && MASCARAS[el.dataset.mask];
      if (!m) return;
      const antes = el.value, pos = el.selectionStart, dAntes = digitos(antes.slice(0, pos)).length;
      el.value = m(antes);
      if (document.activeElement === el && pos != null) {   // mantém o cursor no lugar certo
        let i = 0, n = 0; while (i < el.value.length && n < dAntes) { if (/\d/.test(el.value[i])) n++; i++; }
        try { el.setSelectionRange(i, i); } catch (_) {}
      }
    });
  }

  const formatar = { tel: v => digitos(v) ? mascaraTel(v) : "", cep: v => digitos(v) ? mascaraCep(v) : "", doc: v => digitos(v) ? mascaraDoc(v) : "" };

  global.MC = { digitos, mascaraTel, mascaraCep, mascaraDoc, telValido, cepValido, emailValido, docValido, tipoDoc,
                buscarCep, ligarCep, ligarMascaras, formatar };
})(window);
