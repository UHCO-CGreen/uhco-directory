<!---
    Shared Bootstrap confirm modal for destructive actions.
    Include once per page. Add class="js-confirm-submit" plus data-confirm-* attributes to any form.

    Supported data attributes:
        data-confirm-title   — modal header text (default: "Confirm Action")
        data-confirm-message — modal body text (default: "Are you sure you want to continue?")
        data-confirm-ok      — OK button label (default: "Continue")
        data-confirm-class   — Bootstrap btn- suffix for OK button (default: "primary"; use "danger"/"warning")
--->
<div class="modal fade" id="confirmActionModal" tabindex="-1" aria-labelledby="confirmActionModalLabel" aria-hidden="true">
    <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content">
            <div class="modal-header">
                <h5 class="modal-title" id="confirmActionModalLabel">Confirm Action</h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body" id="confirmActionModalBody">Are you sure?</div>
            <div class="modal-footer">
                <button type="button" class="btn btn-ui-cancel" data-bs-dismiss="modal">Cancel</button>
                <button type="button" class="btn btn-ui-go" id="confirmActionModalOk">Continue</button>
            </div>
        </div>
    </div>
</div>

<cfoutput><script nonce="#encodeForHTMLAttribute(request.cspNonce ?: '')#"></cfoutput>
document.addEventListener('DOMContentLoaded', function () {
    // Spinner for long-running navigation links
    document.querySelectorAll('a.js-spinner-nav').forEach(function (link) {
        link.addEventListener('click', function () {
            link.innerHTML = '<span class="spinner-border spinner-border-sm me-1" role="status" aria-hidden="true"></span>Running&hellip;';
            link.classList.add('disabled');
            link.style.pointerEvents = 'none';
        });
    });

    var confirmModalEl = document.getElementById('confirmActionModal');
    if (!confirmModalEl || !(window.bootstrap && bootstrap.Modal)) { return; }

    var confirmModal = new bootstrap.Modal(confirmModalEl);
    var titleEl  = document.getElementById('confirmActionModalLabel');
    var bodyEl   = document.getElementById('confirmActionModalBody');
    var okBtn    = document.getElementById('confirmActionModalOk');
    var pendingForm = null;

    document.querySelectorAll('form.js-confirm-submit').forEach(function (form) {
        form.addEventListener('submit', function (evt) {
            evt.preventDefault();
            pendingForm = form;
            titleEl.textContent  = form.getAttribute('data-confirm-title')   || 'Confirm Action';
            bodyEl.textContent   = form.getAttribute('data-confirm-message') || 'Are you sure you want to continue?';
            okBtn.textContent    = form.getAttribute('data-confirm-ok')      || 'Continue';
            okBtn.className      = 'btn btn-' + (form.getAttribute('data-confirm-class') || 'primary');
            confirmModal.show();
        });
    });

    okBtn.addEventListener('click', function () {
        if (pendingForm) {
            var formToSubmit = pendingForm;
            pendingForm = null;
            okBtn.disabled = true;
            okBtn.innerHTML = '<span class="spinner-border spinner-border-sm me-1" role="status" aria-hidden="true"></span>Working&hellip;';
            confirmModal.hide();
            formToSubmit.submit();
        }
    });

    // Re-enable OK button if modal is dismissed without submitting (e.g. Cancel)
    confirmModalEl.addEventListener('hidden.bs.modal', function () {
        if (!pendingForm) {
            okBtn.disabled = false;
        }
    });
});
</script>
