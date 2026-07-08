(function () {
    function ensureToastElements() {
        var toastEl = document.getElementById('adminUiToast');
        var toastBody = document.getElementById('adminUiToastBody');

        if (toastEl && toastBody) {
            return { toastEl: toastEl, toastBody: toastBody };
        }

        var container = document.getElementById('adminUiToastContainer');
        if (!container) {
            container = document.createElement('div');
            container.id = 'adminUiToastContainer';
            container.className = 'toast-container position-fixed bottom-0 end-0 p-3';
            document.body.appendChild(container);
        }

        toastEl = document.createElement('div');
        toastEl.id = 'adminUiToast';
        toastEl.className = 'toast align-items-center border-0';
        toastEl.setAttribute('role', 'status');
        toastEl.setAttribute('aria-live', 'polite');
        toastEl.setAttribute('aria-atomic', 'true');
        toastEl.innerHTML = "<div class='d-flex'><div class='toast-body fw-semibold' id='adminUiToastBody'></div><button type='button' class='btn-close btn-close-white me-2 m-auto' data-bs-dismiss='toast' aria-label='Close'></button></div>";
        container.appendChild(toastEl);

        toastBody = document.getElementById('adminUiToastBody');
        return { toastEl: toastEl, toastBody: toastBody };
    }

    function resolveToastElements(options) {
        var opts = options || {};
        var toastEl = opts.toastId ? document.getElementById(opts.toastId) : null;
        var toastBody = opts.bodyId ? document.getElementById(opts.bodyId) : null;

        if (toastEl && toastBody) {
            return { toastEl: toastEl, toastBody: toastBody };
        }

        return ensureToastElements();
    }

    function getToneClass(tone) {
        var normalizedTone = String(tone || 'success').toLowerCase();
        if (normalizedTone === 'danger' || normalizedTone === 'error') {
            return 'text-bg-danger';
        }
        if (normalizedTone === 'warning') {
            return 'text-bg-warning';
        }
        if (normalizedTone === 'info') {
            return 'text-bg-info';
        }
        return 'text-bg-success';
    }

    function showToast(message, options) {
        var opts = options || {};
        var resolved = resolveToastElements(opts);
        var toastEl = resolved.toastEl;
        var toastBody = resolved.toastBody;

        if (!toastEl || !toastBody) {
            return;
        }

        toastBody.textContent = String(message || '');
        toastEl.classList.remove('text-bg-success', 'text-bg-danger', 'text-bg-warning', 'text-bg-info');
        toastEl.classList.add(getToneClass(opts.tone));

        if (window.bootstrap && window.bootstrap.Toast) {
            window.bootstrap.Toast.getOrCreateInstance(toastEl, { delay: opts.delay || 3000 }).show();
        }
    }

    function showError(message, options) {
        var opts = Object.assign({}, options || {}, { tone: 'danger' });
        showToast(message, opts);
    }

    function showSuccess(message, options) {
        var opts = Object.assign({}, options || {}, { tone: 'success' });
        showToast(message, opts);
    }

    function confirmAction(message) {
        return window.confirm(String(message || 'Are you sure?'));
    }

    function copyText(text, options) {
        var value = String(text || '');
        if (!navigator.clipboard || !navigator.clipboard.writeText) {
            showError('Clipboard copy is not available in this browser.', options);
            return Promise.resolve(false);
        }

        return navigator.clipboard.writeText(value)
            .then(function () {
                showSuccess((options && options.successMessage) || 'Copied to clipboard.', options);
                return true;
            })
            .catch(function (err) {
                showError((options && options.errorMessage) || ('Clipboard copy failed: ' + (err && err.message ? err.message : 'Unknown error')), options);
                return false;
            });
    }

    function initPlainTextQuill(selectorOrElement, options) {
        if (!window.Quill) {
            return null;
        }

        var editorEl = typeof selectorOrElement === 'string'
            ? document.querySelector(selectorOrElement)
            : selectorOrElement;

        if (!editorEl) {
            return null;
        }

        var opts = options || {};
        var quill = new window.Quill(editorEl, {
            theme: 'snow',
            placeholder: opts.placeholder || '',
            modules: opts.modules || {
                toolbar: [
                    ['bold', 'italic'],
                    ['link'],
                    [{ list: 'ordered' }, { list: 'bullet' }],
                    ['clean']
                ],
                clipboard: { matchVisual: false }
            }
        });

        var Delta = window.Quill.import('delta');
        quill.clipboard.addMatcher(Node.ELEMENT_NODE, function (node) {
            var plaintext = node.textContent || '';
            return new Delta().insert(plaintext);
        });

        return quill;
    }

    window.AdminUI = window.AdminUI || {};
    window.AdminUI.showToast = showToast;
    window.AdminUI.showError = showError;
    window.AdminUI.showSuccess = showSuccess;
    window.AdminUI.confirmAction = confirmAction;
    window.AdminUI.copyText = copyText;
    window.AdminUI.initPlainTextQuill = initPlainTextQuill;
})();