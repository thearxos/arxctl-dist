// Offline Codex cheatsheets: copy buttons on code blocks, and the search on the home page.
// Works from file:// (no fetch): the search index is a plain script that sets window.CX_INDEX.
(function () {
  document.querySelectorAll(".cx-code").forEach(function (fig) {
    var b = document.createElement("button");
    b.type = "button"; b.className = "cx-copy"; b.textContent = "Copy";
    b.addEventListener("click", function () {
      var code = fig.querySelector("code").textContent;
      var done = function () { b.textContent = "Copied"; setTimeout(function () { b.textContent = "Copy"; }, 1500); };
      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(code).then(done, function () { fallback(code); done(); });
      } else { fallback(code); done(); }
    });
    fig.appendChild(b);
  });
  function fallback(text) {
    var t = document.createElement("textarea");
    t.value = text; t.style.position = "fixed"; t.style.opacity = "0";
    document.body.appendChild(t); t.select();
    try { document.execCommand("copy"); } catch (e) {}
    t.remove();
  }

  var q = document.getElementById("cx-q");
  if (!q || !window.CX_INDEX) return;
  var list = document.getElementById("cx-results"), count = document.getElementById("cx-count");
  var docs = window.CX_INDEX.map(function (d) {
    return { d: d, t: d.t.toLowerCase(), h: d.h.toLowerCase(), s: (d.s + " " + d.g + " " + d.d).toLowerCase(), x: d.x.toLowerCase() };
  });
  function esc(s) { return s.replace(/[&<>"]/g, function (c) { return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]; }); }
  function mark(text, terms) {
    var out = esc(text);
    terms.forEach(function (w) {
      var e = esc(w).replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
      out = out.replace(new RegExp("(" + e + ")", "gi"), "<mark>$1</mark>");
    });
    return out;
  }
  function snippet(doc, terms) {
    var i = doc.x.indexOf(terms[0]);
    if (i < 0) return doc.d.d;
    var start = Math.max(0, i - 60);
    return (start ? "..." : "") + doc.d.x.slice(start, i + 140) + "...";
  }
  function run() {
    var terms = q.value.toLowerCase().split(/\s+/).filter(Boolean);
    list.innerHTML = "";
    if (!terms.length) { count.textContent = ""; return; }
    var hits = [];
    docs.forEach(function (doc) {
      var score = 0;
      for (var k = 0; k < terms.length; k++) {
        var w = terms[k], s = 0;
        if (doc.t.indexOf(w) >= 0) s += 10;
        if (doc.h.indexOf(w) >= 0) s += 5;
        if (doc.s.indexOf(w) >= 0) s += 3;
        if (doc.x.indexOf(w) >= 0) s += 1;
        if (!s) return;
        score += s;
      }
      hits.push({ doc: doc, score: score });
    });
    hits.sort(function (a, b) { return b.score - a.score; });
    count.textContent = hits.length ? hits.length + (hits.length === 1 ? " page" : " pages") : "No page matches all of those words.";
    hits.slice(0, 40).forEach(function (h) {
      var li = document.createElement("li");
      li.innerHTML = '<a href="' + esc(h.doc.d.u) + '">' + mark(h.doc.d.t, terms) + "</a><small>" + esc(h.doc.d.s + " › " + h.doc.d.g) +
        "</small><small>" + mark(snippet(h.doc, terms), terms) + "</small>";
      list.appendChild(li);
    });
  }
  var timer;
  q.addEventListener("input", function () { clearTimeout(timer); timer = setTimeout(run, 80); });
  // index.html#q=words opens with that search done (the Control Center links searches this way)
  if (location.hash.indexOf("#q=") === 0) { q.value = decodeURIComponent(location.hash.slice(3)); run(); }
  if (location.hash === "#search" || location.hash.indexOf("#q=") === 0) q.focus();
})();
