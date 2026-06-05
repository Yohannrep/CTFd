from pathlib import Path


navbar_path = Path("/opt/CTFd/CTFd/themes/core/templates/components/navbar.html")
marker = "components/labs_modal.html"

labs_markup = """
{# Cyber range Labs controls. Added by docker/ctfd/patch_navbar.py. #}
<li class="nav-item">
  <button
    id="labs-open-button"
    class="btn btn-sm btn-primary labs-nav-button my-2 my-md-0"
    type="button"
    data-labs-open
  >
    Labs
  </button>
</li>
{% include "components/labs_modal.html" %}
"""


html = navbar_path.read_text(encoding="utf-8")

if marker in html:
    print("Labs navbar markup already exists; skipping patch.")
else:
    insert_at = html.rfind("</ul>")
    if insert_at == -1:
        insert_at = html.rfind("</nav>")

    if insert_at == -1:
        html = html.rstrip() + "\n" + labs_markup + "\n"
    else:
        html = html[:insert_at] + labs_markup + "\n" + html[insert_at:]

    navbar_path.write_text(html, encoding="utf-8")
