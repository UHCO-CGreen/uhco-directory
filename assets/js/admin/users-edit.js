/* ══════════════════════════════════════════════════════════
   Modal + AJAX CRUD for all repeating sections
   Each section: cards (display) + hidden inputs (data) + modal (edit) + AJAX save
   ══════════════════════════════════════════════════════════ */
document.addEventListener('DOMContentLoaded', function () {

    var adminUI = window.AdminUI || {};
    var sharedToastOptions = { toastId: 'saveToast', bodyId: 'saveToastBody' };
    var honorsSet = {
        'Gold Key': 1,
        'Summa Cum Laude': 1,
        'Magna Cum Laude': 1,
        'BSK Gold': 1,
        'BSK Black & Gold': 1,
        'AOSA Honors': 1,
        'NOSA Honors': 1
    };

    var dirtySectionButtons = {
        general: 'save-general-btn',
        flags: 'save-flags-btn',
        orgs: 'save-orgs-btn',
        extids: 'save-extids-btn',
        publications: 'save-publications-btn',
        emails: 'saveEmailsBtn',
        phones: 'savePhonesBtn',
        aliases: 'saveAliasesBtn',
        addresses: 'saveAddressesBtn',
        degrees: 'saveDegreesBtn',
        awards: 'saveAwardsBtn',
        uh: 'save-uh-btn',
        bioinfo: 'save-bioinfo-btn'
    };

    function setSectionDirty(section, isDirty) {
        var entry = dirtySectionButtons[section];
        if (!entry) return;
        var buttonIds = Array.isArray(entry) ? entry : [entry];
        buttonIds.forEach(function (buttonId) {
            var btn = document.getElementById(buttonId);
            if (!btn) return;
            btn.classList.add('btn-save-action');
            btn.classList.toggle('users-edit-save-needs', !!isDirty);
            btn.classList.toggle('btn-save-needs', !!isDirty);

            var badgeId = buttonId + '-unsaved-badge';
            var badge = document.getElementById(badgeId);
            if (isDirty) {
                if (!badge) {
                    badge = document.createElement('span');
                    badge.id = badgeId;
                    badge.className = 'badge rounded-pill bg-warning text-dark ms-2';
                    badge.textContent = 'Unsaved';
                    btn.insertAdjacentElement('beforebegin', badge);
                }
            } else if (badge) {
                badge.remove();
            }
        });
    }

    function markDirty(section) { setSectionDirty(section, true); }
    function clearDirty(section) { setSectionDirty(section, false); }

    function getSaveStatusEl(buttonId, statusId) {
        if (statusId) {
            var statusById = document.getElementById(statusId);
            if (statusById) {
                return statusById;
            }
        }
        var btn = document.getElementById(buttonId);
        if (!btn || !btn.parentNode) {
            return null;
        }
        var status = btn.parentNode.querySelector('.save-status');
        if (!status) {
            status = document.createElement('span');
            status.className = 'save-status';
            btn.parentNode.appendChild(status);
        }
        return status;
    }

    function wireSectionDirty(section, rootEl) {
        if (!rootEl) return;
        rootEl.addEventListener('input', function () { markDirty(section); });
        rootEl.addEventListener('change', function () { markDirty(section); });
    }

    function wireRepeaterDirty(section, containerEl) {
        if (!containerEl || typeof MutationObserver === 'undefined') return;
        var observer = new MutationObserver(function () { markDirty(section); });
        observer.observe(containerEl, { childList: true, subtree: true });
    }

    function escapeForAttributeSelector(value) {
        return String(value || '').replace(/\\/g, '\\\\').replace(/"/g, '\\"');
    }

    function replaceContainerFromFresh(currentPane, freshPane, containerId) {
        if (!currentPane || !freshPane) return;
        var currentContainer = currentPane.querySelector('#' + containerId);
        var freshContainer = freshPane.querySelector('#' + containerId);
        if (currentContainer && freshContainer) {
            currentContainer.innerHTML = freshContainer.innerHTML;
        }
    }

    function syncNamedFieldsFromFresh(currentPane, freshPane) {
        if (!currentPane || !freshPane) return;
        var freshFields = freshPane.querySelectorAll('input[name], select[name], textarea[name]');
        freshFields.forEach(function (freshField) {
            var name = freshField.getAttribute('name') || '';
            if (!name) return;

            var selector = '[name="' + escapeForAttributeSelector(name) + '"]';
            var currentFields = currentPane.querySelectorAll(selector);
            if (!currentFields.length) return;

            if (freshField.type === 'checkbox' || freshField.type === 'radio') {
                currentFields.forEach(function (currentField) {
                    if ((currentField.value || '') === (freshField.value || '')) {
                        currentField.checked = !!freshField.checked;
                    }
                });
                return;
            }

            var currentField = currentFields[0];
            if (currentField) {
                currentField.value = freshField.value;
            }
        });
    }

    function fetchFreshEditDocument() {
        return fetch(window.location.pathname + window.location.search, {
            method: 'GET',
            credentials: 'same-origin',
            headers: { 'X-Requested-With': 'XMLHttpRequest' },
            cache: 'no-store'
        })
        .then(function (r) { return r.text(); })
        .then(function (html) {
            return new DOMParser().parseFromString(html, 'text/html');
        });
    }

    function normalizeFlagName(flagName) {
        return String(flagName || '')
            .toLowerCase()
            .trim()
            .replace(/[\s_]+/g, '-')
            .replace(/-+/g, '-');
    }

    function hasAnyCheckedFlagName(normalizedNames) {
        var pane = document.getElementById('flags-pane');
        if (!pane) return false;

        var checked = pane.querySelectorAll('input[name="Flags"]:checked');
        for (var i = 0; i < checked.length; i++) {
            var normalized = normalizeFlagName(checked[i].getAttribute('data-flagname'));
            if (normalizedNames.indexOf(normalized) !== -1) {
                return true;
            }
        }
        return false;
    }

    function hasAnyCheckedFlagToken(flagTokens) {
        var pane = document.getElementById('flags-pane');
        if (!pane) return false;

        var checked = pane.querySelectorAll('input[name="Flags"]:checked');
        for (var i = 0; i < checked.length; i++) {
            var normalized = normalizeFlagName(checked[i].getAttribute('data-flagname'));
            for (var j = 0; j < flagTokens.length; j++) {
                if (normalized.indexOf(flagTokens[j]) !== -1) {
                    return true;
                }
            }
        }
        return false;
    }

    function shouldShowDegreesAwardsFromFlagsPane() {
        return (
            hasAnyCheckedFlagToken(['faculty']) ||
            hasAnyCheckedFlagToken(['alumni']) ||
            hasAnyCheckedFlagToken(['current-student', 'current-students']) ||
            hasAnyCheckedFlagToken(['emeritus']) ||
            hasAnyCheckedFlagToken(['resident'])
        );
    }

    function shouldShowFacultyBioFromFlagsPane() {
        return hasAnyCheckedFlagToken(['faculty']);
    }

    function toggleDisplayById(id, isVisible) {
        var el = document.getElementById(id);
        if (!el) return;
        el.classList.toggle('d-none', !isVisible);
        el.hidden = !isVisible;
    }

    function syncBiographicalDegreesAwardsVisibility(isVisible) {
        toggleDisplayById('bioActionsLabel', isVisible);
        toggleDisplayById('addDegreeBtn', isVisible);
        toggleDisplayById('addAwardBtn', isVisible);
        toggleDisplayById('degreesSaveStatus', isVisible);
        toggleDisplayById('awardsSaveStatus', isVisible);
        toggleDisplayById('bioDegreesAwardsDivider', isVisible);
        toggleDisplayById('bioDegreesAwardsHeading', isVisible);
        toggleDisplayById('bioDegreesSection', isVisible);
        toggleDisplayById('bioAwardsSection', isVisible);
    }

    function syncBiographicalFacultyVisibility(isVisible) {
        toggleDisplayById('bioFacultySection', isVisible);
    }

    function getRefreshButtonIdByTab(tabId) {
        var map = {
            'general-tab': 'refreshGeneralInfoBtn',
            'contact-tab': 'refreshContactInfoBtn',
            'bio-info-tab': 'refreshBiographicalInfoBtn',
            'flags-tab': 'refreshFlagsBtn',
            'orgs-tab': 'refreshOrgsBtn',
            'extids-tab': 'refreshExtidsBtn',
            'admin-tab': 'refreshUhBtn'
        };
        return map[tabId] || '';
    }

    function setRefreshButtonLoading(tabId, isLoading) {
        var buttonId = getRefreshButtonIdByTab(tabId);
        if (!buttonId) return;
        var btn = document.getElementById(buttonId);
        if (!btn) return;

        var loadingCount = parseInt(btn.getAttribute('data-refresh-loading-count') || '0', 10);
        if (isLoading) {
            loadingCount += 1;
            if (loadingCount === 1) {
                btn.setAttribute('data-refresh-original-html', btn.innerHTML);
                btn.disabled = true;
                btn.innerHTML = "<span class='spinner-border spinner-border-sm me-1' role='status' aria-hidden='true'></span>Refreshing...";
            }
        } else {
            loadingCount = Math.max(0, loadingCount - 1);
            if (loadingCount === 0) {
                var originalHtml = btn.getAttribute('data-refresh-original-html');
                if (originalHtml) {
                    btn.innerHTML = originalHtml;
                }
                btn.disabled = false;
            }
        }

        btn.setAttribute('data-refresh-loading-count', String(loadingCount));
    }

    function refreshTabData(tabId) {
        var tabBtn = tabId ? document.getElementById(tabId) : null;
        var paneTarget = tabBtn ? (tabBtn.getAttribute('data-bs-target') || '') : '';
        if (!paneTarget || paneTarget.charAt(0) !== '#') {
            return Promise.resolve();
        }

        var paneId = paneTarget.substring(1);
        var currentPane = document.getElementById(paneId);
        if (!currentPane) {
            return Promise.resolve();
        }

        setRefreshButtonLoading(tabId, true);

        return fetchFreshEditDocument().then(function (freshDoc) {
            var freshPane = freshDoc.getElementById(paneId);
            if (!freshPane) {
                return;
            }

            syncNamedFieldsFromFresh(currentPane, freshPane);

            if (tabId === 'general-tab') {
                replaceContainerFromFresh(currentPane, freshPane, 'aliasesContainer');
                clearDirty('aliases');
            }
            if (tabId === 'contact-tab') {
                replaceContainerFromFresh(currentPane, freshPane, 'emailsContainer');
                replaceContainerFromFresh(currentPane, freshPane, 'phonesContainer');
                replaceContainerFromFresh(currentPane, freshPane, 'addressesContainer');
                clearDirty('emails');
                clearDirty('phones');
                clearDirty('addresses');
            }
            if (tabId === 'bio-info-tab') {
                replaceContainerFromFresh(currentPane, freshPane, 'degreesContainer');
                replaceContainerFromFresh(currentPane, freshPane, 'awardsContainer');
                replaceContainerFromFresh(currentPane, freshPane, 'residenciesContainer');
                clearDirty('degrees');
                clearDirty('awards');
                clearDirty('residencies');
            }
            if (tabId === 'publications-tab') {
                replaceContainerFromFresh(currentPane, freshPane, 'publicationsPanels');
                clearDirty('publications');
            }
        }).catch(function () {
            showSaveToast('Refresh failed. Please try again.', true);
        }).finally(function () {
            setRefreshButtonLoading(tabId, false);
        });
    }

    /* ── Save toast helper ── */
    function showSaveToast(message, isError) {
        if (adminUI.showToast) {
            adminUI.showToast(message, Object.assign({}, sharedToastOptions, {
                tone: isError ? 'danger' : 'success'
            }));
        }
    }

    function showValidationError(message) {
        showSaveToast(message, true);
    }

    function parseFlagIdList(value) {
        return String(value || '')
            .split(',')
            .map(function (item) { return item.trim(); })
            .filter(function (item) { return item.length > 0; });
    }

    function isAnyFlagChecked(flagIds) {
        return (flagIds || []).some(function (id) {
            var cb = document.querySelector('input[name="Flags"][value="' + id + '"]');
            return cb && cb.checked;
        });
    }

    function setTabVisibility(tabListId, tabButtonId, isVisible, onHide) {
        var tabLi = document.getElementById(tabListId);
        var tabBtn = document.getElementById(tabButtonId);
        if (!tabLi || !tabBtn) {
            return;
        }

        tabLi.classList.toggle('d-none', !isVisible);
        if (!isVisible && tabBtn.classList.contains('active')) {
            if (typeof onHide === 'function') {
                onHide();
            }

            var generalTab = document.getElementById('general-tab');
            if (generalTab && window.bootstrap && window.bootstrap.Tab) {
                window.bootstrap.Tab.getOrCreateInstance(generalTab).show();
            } else if (generalTab) {
                generalTab.click();
            }
        }
    }

    function syncCurrentStudentGradYears() {
        var curr = document.getElementById('currentGradYear');
        var orig = document.getElementById('originalGradYear');
        if (!curr || !orig) {
            return;
        }

        var hasValue = curr.value.trim().length > 0;
        orig.disabled = !hasValue;
        if (!hasValue) {
            orig.value = '';
        }
    }

    function initUsersEditPageChrome() {
        if (window.bootstrap) {
            document.querySelectorAll('[data-bs-toggle="tooltip"]').forEach(function (el) {
                window.bootstrap.Tooltip.getOrCreateInstance(el);
            });
        }

        var tabList = document.getElementById('editTabs');
        if (!tabList) {
            return;
        }

        var requestedTabId = new URL(window.location.href).searchParams.get('tab') || '';
        var requestedTab = requestedTabId ? document.getElementById(requestedTabId) : null;
        if (requestedTab && requestedTab.getAttribute('data-bs-toggle') === 'tab' && window.bootstrap && window.bootstrap.Tab) {
            window.bootstrap.Tab.getOrCreateInstance(requestedTab).show();
        }

        tabList.addEventListener('shown.bs.tab', function (event) {
            var shownTab = event && event.target ? event.target : null;
            if (!shownTab || !shownTab.id) {
                return;
            }

            var nextUrl = new URL(window.location.href);
            nextUrl.searchParams.set('tab', shownTab.id);
            history.replaceState(null, '', nextUrl.toString());

            window.dispatchEvent(new CustomEvent('users-edit-tab-selected', {
                detail: { tabId: shownTab.id }
            }));
        });
    }

    function initRefreshPageButton() {
        var refreshButton = document.getElementById('refreshPageBtn');
        if (!refreshButton) {
            return;
        }

        refreshButton.addEventListener('click', function () {
            window.location.reload();
        });
    }

    function initDataQualityPanelToggle() {
        var panel = document.getElementById('dataQualityPanel');
        var adminTab = document.getElementById('admin-tab');
        var tabList = document.getElementById('editTabs');

        if (!panel || !adminTab || !tabList) {
            return;
        }

        function syncDataQualityPanel() {
            var showPanel = adminTab.classList.contains('active');
            panel.classList.toggle('d-none', !showPanel);
        }

        syncDataQualityPanel();
        tabList.addEventListener('shown.bs.tab', syncDataQualityPanel);
    }

    function initFlagDrivenTabVisibility() {
        var pageRoot = document.querySelector('.users-edit-page');
        if (!pageRoot) {
            return;
        }

        var emeritusFlagIds = parseFlagIdList(pageRoot.getAttribute('data-emeritus-flag-ids'));
        var residentFlagIds = parseFlagIdList(pageRoot.getAttribute('data-resident-flag-ids'));
        var publicFacingCb = document.querySelector('input[name="Flags"][data-flagname="public-facing"]');
        var autoPublicFacingNames = ['clinical-attending', 'faculty-adjunct', 'faculty-fulltime', 'professor-emeritus', 'accepting-patients'];

        function syncProfileTabs() {
            setTabVisibility('emeritus-profile-tab-li', 'emeritus-profile-tab', isAnyFlagChecked(emeritusFlagIds));
            setTabVisibility('resident-profile-tab-li', 'resident-profile-tab', isAnyFlagChecked(residentFlagIds));
        }

        document.querySelectorAll('input[name="Flags"]').forEach(function (cb) {
            cb.addEventListener('change', syncProfileTabs);

            if (!publicFacingCb) {
                return;
            }

            var flagName = String(cb.getAttribute('data-flagname') || '').toLowerCase();
            if (autoPublicFacingNames.indexOf(flagName) === -1) {
                return;
            }

            cb.addEventListener('change', function () {
                if (cb.checked) {
                    publicFacingCb.checked = true;
                    syncProfileTabs();
                }
            });
        });

        var currentGradYear = document.getElementById('currentGradYear');
        if (currentGradYear) {
            currentGradYear.addEventListener('input', syncCurrentStudentGradYears);
        }

        syncCurrentStudentGradYears();
        syncProfileTabs();
    }

    function initFlagCardToggle() {
        var flagsPane = document.getElementById('flags-pane');
        if (!flagsPane) {
            return;
        }

        flagsPane.addEventListener('click', function (event) {
            var card = event.target.closest('.users-edit-flag-card');
            if (!card || !flagsPane.contains(card)) {
                return;
            }

            if (event.target.closest('input, label, a, button')) {
                return;
            }

            var checkboxId = card.getAttribute('data-flag-checkbox-id');
            if (!checkboxId) {
                return;
            }

            var checkbox = document.getElementById(checkboxId);
            if (!checkbox || checkbox.disabled) {
                return;
            }

            checkbox.checked = !checkbox.checked;
            checkbox.dispatchEvent(new Event('change', { bubbles: true }));
        });
    }

    function initDegreePanels() {
        var prefixes = ['fac', 'emer', 'res'];

        function updateComposite(prefix) {
            var container = document.getElementById(prefix + '_degreesContainer');
            var composite = document.getElementById(prefix + '_composite');
            if (!container || !composite) {
                return;
            }

            var names = [];
            container.querySelectorAll('[data-field="deg_name"]').forEach(function (input) {
                var value = input.value.trim();
                if (value) {
                    names.push(value);
                }
            });
            composite.value = names.join(', ');
        }

        function reindexRows(prefix, container, countInput) {
            var rows = container.querySelectorAll('.degree-row');
            rows.forEach(function (row, index) {
                var nameInput = row.querySelector('[data-field="deg_name"]');
                var universityInput = row.querySelector('[data-field="deg_univ"]');
                var yearInput = row.querySelector('[data-field="deg_year"]');
                if (nameInput) { nameInput.name = prefix + '_deg_name_' + index; }
                if (universityInput) { universityInput.name = prefix + '_deg_univ_' + index; }
                if (yearInput) { yearInput.name = prefix + '_deg_year_' + index; }
            });
            countInput.value = rows.length;
            updateComposite(prefix);
        }

        function makeRemovable(prefix, container, countInput, button) {
            button.addEventListener('click', function () {
                var row = button.closest('.degree-row');
                if (row) {
                    row.remove();
                    reindexRows(prefix, container, countInput);
                }
            });
        }

        prefixes.forEach(function (prefix) {
            var container = document.getElementById(prefix + '_degreesContainer');
            var countInput = document.getElementById(prefix + '_degreeCount');
            if (!container || !countInput) {
                return;
            }

            container.querySelectorAll('.remove-degree-row').forEach(function (button) {
                makeRemovable(prefix, container, countInput, button);
            });

            container.querySelectorAll('[data-field="deg_name"]').forEach(function (input) {
                input.addEventListener('input', function () {
                    updateComposite(prefix);
                });
            });
        });

        document.addEventListener('click', function (event) {
            var addButton = event.target.closest('.add-degree-row');
            if (!addButton) {
                return;
            }

            var prefix = addButton.getAttribute('data-prefix');
            var container = document.getElementById(prefix + '_degreesContainer');
            var countInput = document.getElementById(prefix + '_degreeCount');
            if (!prefix || !container || !countInput) {
                return;
            }

            var index = parseInt(countInput.value, 10) || 0;
            var row = document.createElement('div');
            row.className = 'row g-2 mb-2 degree-row';
            row.innerHTML = "<div class='col-md-4'><input class='form-control form-control-sm' name='" + prefix + "_deg_name_" + index + "' data-field='deg_name' placeholder='Degree (required)' required></div>" +
                "<div class='col-md-4'><input class='form-control form-control-sm' name='" + prefix + "_deg_univ_" + index + "' data-field='deg_univ' placeholder='University'></div>" +
                "<div class='col-md-2'><input class='form-control form-control-sm' name='" + prefix + "_deg_year_" + index + "' data-field='deg_year' placeholder='Year'></div>" +
                "<div class='col-md-2'><button type='button' class='btn btn-sm btn-remove remove-degree-row w-100'><i class='bi bi-trash me-1'></i>Remove</button></div>";
            container.appendChild(row);
            countInput.value = index + 1;

            var removeButton = row.querySelector('.remove-degree-row');
            if (removeButton) {
                makeRemovable(prefix, container, countInput, removeButton);
            }
            var nameInput = row.querySelector('[data-field="deg_name"]');
            if (nameInput) {
                nameInput.addEventListener('input', function () {
                    updateComposite(prefix);
                });
            }
            updateComposite(prefix);
        });
    }

    function initRecordStatusToggle() {
        var sw = document.getElementById('activeSwitch');
        var label = document.getElementById('activeSwitchLabel');
        var statusCard = document.querySelector('.users-edit-record-status');
        if (!sw) {
            return;
        }

        function setStatusCardState(isActive) {
            if (!statusCard) {
                return;
            }
            statusCard.classList.toggle('users-edit-record-status-active', !!isActive);
            statusCard.classList.toggle('users-edit-record-status-inactive', !isActive);
        }

        function triggerStatusToggle() {
            if (!sw.disabled) {
                sw.click();
            }
        }

        setStatusCardState(sw.checked);

        if (statusCard) {
            statusCard.addEventListener('click', function (event) {
                if (event.target && event.target.closest('.form-check')) {
                    return;
                }
                triggerStatusToggle();
            });

            statusCard.addEventListener('keydown', function (event) {
                if (event.key === 'Enter' || event.key === ' ') {
                    event.preventDefault();
                    triggerStatusToggle();
                }
            });
        }

        sw.addEventListener('change', function () {
            var body = new URLSearchParams();
            body.append('userID', sw.dataset.userid);
            body.append('active', sw.checked ? 1 : 0);
            sw.disabled = true;

            fetch('/admin/users/toggleActive.cfm', {
                method: 'POST',
                headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
                credentials: 'same-origin',
                body: body.toString()
            })
                .then(function (response) { return response.json(); })
                .then(function (data) {
                    if (data.success) {
                        if (label) {
                            label.textContent = data.active ? 'Active' : 'Inactive';
                        }
                        setStatusCardState(data.active);
                        return;
                    }

                    sw.checked = !sw.checked;
                    setStatusCardState(sw.checked);
                    showSaveToast('Could not update status: ' + (data.message || 'Unknown error'), true);
                })
                .catch(function () {
                    sw.checked = !sw.checked;
                    setStatusCardState(sw.checked);
                    showSaveToast('Network error. Status was not saved.', true);
                })
                .finally(function () {
                    sw.disabled = false;
                });
        });
    }

    function initEmailPrimaryValidation() {
        var inputEl = document.getElementById('emailPrimary');
        var errorEl = document.getElementById('emailPrimaryErr');
        if (!inputEl || !errorEl) {
            return;
        }

        function showError(message) {
            inputEl.classList.add('is-invalid');
            errorEl.textContent = message;
        }

        function clearError() {
            inputEl.classList.remove('is-invalid');
            errorEl.textContent = '';
        }

        function validatePrimary() {
            var value = inputEl.value.trim().toLowerCase();
            if (value && !value.endsWith('@uh.edu')) {
                showError('Must be a @uh.edu address (e.g. jsmith@uh.edu).');
                return false;
            }

            clearError();
            return true;
        }

        inputEl.addEventListener('input', validatePrimary);
        inputEl.addEventListener('blur', validatePrimary);
    }

    function initOrgRoleModal() {
        var orgCheckboxes = Array.prototype.slice.call(document.querySelectorAll('input.org-checkbox'));
        var modalEl = document.getElementById('orgRoleModal');
        var modalSaveBtn = document.getElementById('save-orgRoleModal-btn');
        var modalOrgName = document.getElementById('orgRoleModalOrgName');
        var modalTitle = document.getElementById('modalRoleTitle');
        var modalOrder = document.getElementById('modalRoleOrder');

        if (!orgCheckboxes.length || !modalEl || !modalSaveBtn || !modalOrgName || !modalTitle || !modalOrder || !window.bootstrap) {
            return;
        }

        var bsModal = new window.bootstrap.Modal(modalEl);
        var byOrgId = {};
        var childrenByParent = {};
        var pendingCheckbox = null;

        orgCheckboxes.forEach(function (checkbox) {
            var orgId = checkbox.getAttribute('data-orgid') || '';
            var parentId = checkbox.getAttribute('data-parentorgid') || '';
            byOrgId[orgId] = checkbox;
            if (!childrenByParent[parentId]) {
                childrenByParent[parentId] = [];
            }
            childrenByParent[parentId].push(checkbox);
        });

        function getEditButton(orgId) {
            var checkbox = byOrgId[orgId];
            return checkbox ? checkbox.parentNode.querySelector('.org-role-edit') : null;
        }

        function setOrgRole(orgId, roleTitle, roleOrder) {
            var titleEl = document.getElementById('roleTitle_' + orgId);
            var orderEl = document.getElementById('roleOrder_' + orgId);
            var checkbox = byOrgId[orgId];

            if (!titleEl) {
                titleEl = document.createElement('input');
                titleEl.type = 'hidden';
                titleEl.name = 'roleTitle_' + orgId;
                titleEl.id = 'roleTitle_' + orgId;
                if (checkbox) {
                    checkbox.parentNode.appendChild(titleEl);
                }
            }

            if (!orderEl) {
                orderEl = document.createElement('input');
                orderEl.type = 'hidden';
                orderEl.name = 'roleOrder_' + orgId;
                orderEl.id = 'roleOrder_' + orgId;
                if (checkbox) {
                    checkbox.parentNode.appendChild(orderEl);
                }
            }

            titleEl.value = roleTitle;
            orderEl.value = roleOrder;
        }

        function removeOrgRole(orgId) {
            ['roleTitle_', 'roleOrder_'].forEach(function (prefix) {
                var input = document.getElementById(prefix + orgId);
                if (input) {
                    input.remove();
                }
            });
        }

        function checkAncestors(checkbox) {
            var parentId = checkbox.getAttribute('data-parentorgid') || '';
            while (parentId && byOrgId[parentId]) {
                byOrgId[parentId].checked = true;
                parentId = byOrgId[parentId].getAttribute('data-parentorgid') || '';
            }
        }

        function hasAnyCheckedDescendant(orgId) {
            var stack = (childrenByParent[orgId] || []).slice();
            while (stack.length) {
                var child = stack.pop();
                if (child.checked) {
                    return true;
                }
                var grandchildren = childrenByParent[child.getAttribute('data-orgid') || ''] || [];
                for (var index = 0; index < grandchildren.length; index++) {
                    stack.push(grandchildren[index]);
                }
            }
            return false;
        }

        function uncheckAncestorsIfNoCheckedChildren(checkbox) {
            var parentId = checkbox.getAttribute('data-parentorgid') || '';
            while (parentId && byOrgId[parentId]) {
                if (!hasAnyCheckedDescendant(parentId)) {
                    byOrgId[parentId].checked = false;
                }
                parentId = byOrgId[parentId].getAttribute('data-parentorgid') || '';
            }
        }

        function openRoleModal(checkbox) {
            var orgId = checkbox.getAttribute('data-orgid');
            var orgName = checkbox.getAttribute('data-orgname') || '';
            var titleEl = document.getElementById('roleTitle_' + orgId);
            var orderEl = document.getElementById('roleOrder_' + orgId);
            modalOrgName.textContent = orgName;
            modalTitle.value = titleEl ? titleEl.value : '';
            modalOrder.value = orderEl ? orderEl.value : '';
            modalEl.setAttribute('data-current-orgid', orgId);
            bsModal.show();
        }

        modalSaveBtn.addEventListener('click', function () {
            var orgId = modalEl.getAttribute('data-current-orgid');
            setOrgRole(orgId, modalTitle.value.trim(), modalOrder.value.trim());
            var editButton = getEditButton(orgId);
            if (editButton) {
                editButton.classList.add('is-visible');
            }
            pendingCheckbox = null;
            bsModal.hide();
        });

        modalEl.addEventListener('hidden.bs.modal', function () {
            if (!pendingCheckbox) {
                return;
            }

            var orgId = pendingCheckbox.getAttribute('data-orgid');
            pendingCheckbox.checked = false;
            uncheckAncestorsIfNoCheckedChildren(pendingCheckbox);
            orgCheckboxes.forEach(function (checkbox) {
                var editButton = getEditButton(checkbox.getAttribute('data-orgid'));
                if (editButton) {
                    editButton.classList.toggle('is-visible', checkbox.checked);
                }
            });
            removeOrgRole(orgId);
            pendingCheckbox = null;
        });

        document.querySelectorAll('.org-role-edit').forEach(function (button) {
            button.addEventListener('click', function (event) {
                event.preventDefault();
                var orgId = button.getAttribute('data-orgid');
                var checkbox = byOrgId[orgId];
                if (!checkbox) {
                    return;
                }
                pendingCheckbox = null;
                openRoleModal(checkbox);
            });
        });

        orgCheckboxes.forEach(function (checkbox) {
            if (checkbox.checked) {
                checkAncestors(checkbox);
            }

            checkbox.addEventListener('change', function () {
                var isParent = checkbox.getAttribute('data-isparent') === '1';
                var hasRoles = checkbox.getAttribute('data-additionalroles') === '1';
                if (checkbox.checked) {
                    checkAncestors(checkbox);
                    if (!isParent && hasRoles) {
                        pendingCheckbox = checkbox;
                        openRoleModal(checkbox);
                    }
                } else {
                    uncheckAncestorsIfNoCheckedChildren(checkbox);
                    if (!isParent && hasRoles) {
                        var orgId = checkbox.getAttribute('data-orgid');
                        var editButton = getEditButton(orgId);
                        if (editButton) {
                            editButton.classList.remove('is-visible');
                        }
                        removeOrgRole(orgId);
                    }
                }
            });

            var panelId = checkbox.getAttribute('data-panelid');
            if (!panelId) {
                return;
            }

            checkbox.addEventListener('change', function () {
                if (!checkbox.checked) {
                    return;
                }

                var panelEl = document.getElementById(panelId);
                if (panelEl) {
                    window.bootstrap.Collapse.getOrCreateInstance(panelEl, { toggle: false }).show();
                }
            });
        });
    }

    function initBioEditor(rootEl) {
        if (!adminUI.initPlainTextQuill) {
            return;
        }

        var editorNodes = [];
        if (rootEl) {
            if (rootEl.classList && rootEl.classList.contains('users-edit-bio-editor')) {
                editorNodes = [rootEl];
            } else if (rootEl.querySelectorAll) {
                editorNodes = Array.prototype.slice.call(rootEl.querySelectorAll('.users-edit-bio-editor'));
            }
        } else {
            editorNodes = Array.prototype.slice.call(document.querySelectorAll('.users-edit-bio-editor'));
        }

        editorNodes.forEach(function (editorEl) {
            if (!editorEl || editorEl.classList.contains('ql-container') || editorEl.getAttribute('data-bio-editor-initialized') === '1') {
                return;
            }

            adminUI.initPlainTextQuill(editorEl, {
                placeholder: 'Write a short bio...'
            });
            editorEl.setAttribute('data-bio-editor-initialized', '1');
        });
    }

    /* ── Helper: AJAX save a section ── */
    function ajaxSave(section, body, statusEl, onSuccess) {
        if (statusEl) { statusEl.textContent = ''; }
        return fetch('/admin/users/saveSection.cfm', {
            method: 'POST',
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
            credentials: 'same-origin',
            body: body.toString()
        })
        .then(function (r) { return r.json(); })
        .then(function (data) {
            if (data.success) {
                showSaveToast('Saved successfully.');
                clearDirty(section);
                if (onSuccess) onSuccess(data);
            } else {
                showSaveToast('Error: ' + (data.message || 'Unknown'), true);
            }
            return data;
        })
        .catch(function (err) {
            showSaveToast('Network error: ' + (err && err.message ? err.message : 'Unknown'), true);
            return { success: false, message: err && err.message ? err.message : 'Network error' };
        });
    }

    function esc(v) { return (v || '').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/'/g,'&#39;').replace(/"/g,'&quot;'); }

    /* ────────────────────────────────────────────────────────
       EMAIL SECTION
       ──────────────────────────────────────────────────────── */
    (function () {
        var container = document.getElementById('emailsContainer');
        if (!container) return;
        var modalEl = document.getElementById('emailModal');
        var modal = new bootstrap.Modal(modalEl);

        function getAllData() {
            var items = [];
            var hiddens = container.querySelectorAll('input[data-email-field="addr"]');
            hiddens.forEach(function (el) {
                var idx = el.getAttribute('data-email-idx');
                items.push({
                    addr: el.value,
                    type: (container.querySelector('input[data-email-field="type"][data-email-idx="'+idx+'"]') || {}).value || '',
                    primary: (container.querySelector('input[data-email-field="primary"][data-email-idx="'+idx+'"]') || {}).value || '0'
                });
            });
            return items;
        }

        function rebuild(items) {
            container.innerHTML = '';
            items.forEach(function (d, i) {
                container.insertAdjacentHTML('beforeend',
                    "<div class='card mb-2'><div class='card-body py-2 px-3'>" +
                    "<div class='d-flex justify-content-between align-items-center'><div>" +
                    "<strong>" + esc(d.addr) + "</strong>" +
                    (d.type ? " <span class='badge bg-secondary text-dark'>" + esc(d.type) + "</span>" : "") +
                    (d.primary === '1' ? " <span class='badge bg-success'>Primary</span>" : "") +
                    "</div><div>" +
                    "<button type='button' class='btn btn-sm btn-edit edit-email-btn' data-idx='" + i + "'><i class='bi bi-pencil-square me-1'></i>Edit</button> " +
                    "<button type='button' class='btn btn-sm btn-remove remove-email-btn' data-idx='" + i + "'><i class='bi bi-trash me-1'></i>Remove</button>" +
                    "</div></div></div></div>" +
                    "<input type='hidden' data-email-field='addr' data-email-idx='" + i + "' value='" + esc(d.addr) + "'>" +
                    "<input type='hidden' data-email-field='type' data-email-idx='" + i + "' value='" + esc(d.type) + "'>" +
                    "<input type='hidden' data-email-field='primary' data-email-idx='" + i + "' value='" + (d.primary || '0') + "'>"
                );
            });
        }

        function clearModal() {
            document.getElementById('emailEditIdx').value = '-1';
            document.getElementById('emailAddr').value = '';
            document.getElementById('emailType').value = '';
            document.getElementById('emailPrimaryChk').checked = false;
            document.getElementById('emailModalLabel').textContent = 'Add Email';
        }

        function fillModal(idx) {
            var items = getAllData();
            var d = items[idx];
            document.getElementById('emailEditIdx').value = idx;
            document.getElementById('emailAddr').value = d.addr;
            document.getElementById('emailType').value = d.type;
            document.getElementById('emailPrimaryChk').checked = d.primary === '1';
            document.getElementById('emailModalLabel').textContent = 'Edit Email';
        }

        function readModal() {
            return {
                addr: document.getElementById('emailAddr').value.trim(),
                type: document.getElementById('emailType').value,
                primary: document.getElementById('emailPrimaryChk').checked ? '1' : '0'
            };
        }

        document.getElementById('addEmailBtn').addEventListener('click', function () { clearModal(); modal.show(); });

        document.getElementById('saveEmailModalBtn').addEventListener('click', function () {
            var d = readModal();
            if (!d.addr) { showValidationError('Email address is required.'); return; }
            if (/@uh\.edu\s*$/i.test(d.addr)) { showValidationError('@uh.edu addresses cannot be added here.'); return; }
            var items = getAllData();
            var editIdx = parseInt(document.getElementById('emailEditIdx').value);
            if (editIdx >= 0) { items[editIdx] = d; } else { items.push(d); }
            rebuild(items);
            saveEmailsToDatabase({ hideModalOnSuccess: true });
        });

        container.addEventListener('click', function (e) {
            var btn = e.target.closest('.edit-email-btn');
            if (btn) { fillModal(parseInt(btn.dataset.idx)); modal.show(); return; }
            btn = e.target.closest('.remove-email-btn');
            if (btn) {
                var items = getAllData();
                items.splice(parseInt(btn.dataset.idx), 1);
                rebuild(items);
                saveEmailsToDatabase();
            }
        });

        function saveEmailsToDatabase(options) {
            options = options || {};
            var items = getAllData();
            var body = new URLSearchParams();
            body.append('userID', document.getElementById('pageUserID').value);
            body.append('section', 'emails');
            body.append('count', items.length);
            var primaryIdx = -1;
            items.forEach(function (d, i) {
                body.append('addr_' + i, d.addr);
                body.append('type_' + i, d.type);
                if (d.primary === '1') primaryIdx = i;
            });
            body.append('primary_idx', primaryIdx);
            var status = getSaveStatusEl('saveEmailsBtn', 'emailsSaveStatus');
            if (!status) return Promise.resolve({ success: false, message: 'Save status unavailable' });
            return ajaxSave('emails', body, status).then(function (data) {
                if (data && data.success && options.hideModalOnSuccess) {
                    modal.hide();
                }
                return data;
            });
        }

    })();

    /* ────────────────────────────────────────────────────────
       PHONE SECTION
       ──────────────────────────────────────────────────────── */
    (function () {
        var container = document.getElementById('phonesContainer');
        if (!container) return;
        var modalEl = document.getElementById('phoneModal');
        var modal = new bootstrap.Modal(modalEl);

        function getAllData() {
            var items = [];
            var hiddens = container.querySelectorAll('input[data-phone-field="number"]');
            hiddens.forEach(function (el) {
                var idx = el.getAttribute('data-phone-idx');
                items.push({
                    number: el.value,
                    type: (container.querySelector('input[data-phone-field="type"][data-phone-idx="'+idx+'"]') || {}).value || '',
                    primary: (container.querySelector('input[data-phone-field="primary"][data-phone-idx="'+idx+'"]') || {}).value || '0'
                });
            });
            return items;
        }

        function rebuild(items) {
            container.innerHTML = '';
            items.forEach(function (d, i) {
                container.insertAdjacentHTML('beforeend',
                    "<div class='card mb-2'><div class='card-body py-2 px-3'>" +
                    "<div class='d-flex justify-content-between align-items-center'><div>" +
                    "<strong>" + esc(d.number) + "</strong>" +
                    (d.type ? " <span class='badge bg-secondary text-dark'>" + esc(d.type) + "</span>" : "") +
                    (d.primary === '1' ? " <span class='badge bg-success'>Primary</span>" : "") +
                    "</div><div>" +
                    "<button type='button' class='btn btn-sm btn-edit edit-phone-btn' data-idx='" + i + "'><i class='bi bi-pencil-square me-1'></i>Edit</button> " +
                    "<button type='button' class='btn btn-sm btn-remove remove-phone-btn' data-idx='" + i + "'><i class='bi bi-trash me-1'></i>Remove</button>" +
                    "</div></div></div></div>" +
                    "<input type='hidden' data-phone-field='number' data-phone-idx='" + i + "' value='" + esc(d.number) + "'>" +
                    "<input type='hidden' data-phone-field='type' data-phone-idx='" + i + "' value='" + esc(d.type) + "'>" +
                    "<input type='hidden' data-phone-field='primary' data-phone-idx='" + i + "' value='" + (d.primary || '0') + "'>"
                );
            });
        }

        function clearModal() {
            document.getElementById('phoneEditIdx').value = '-1';
            document.getElementById('phoneNumber').value = '';
            document.getElementById('phoneType').value = '';
            document.getElementById('phonePrimaryChk').checked = false;
            document.getElementById('phoneModalLabel').textContent = 'Add Phone';
        }

        function fillModal(idx) {
            var items = getAllData();
            var d = items[idx];
            document.getElementById('phoneEditIdx').value = idx;
            document.getElementById('phoneNumber').value = d.number;
            document.getElementById('phoneType').value = d.type;
            document.getElementById('phonePrimaryChk').checked = d.primary === '1';
            document.getElementById('phoneModalLabel').textContent = 'Edit Phone';
        }

        function readModal() {
            return {
                number: document.getElementById('phoneNumber').value.trim(),
                type: document.getElementById('phoneType').value,
                primary: document.getElementById('phonePrimaryChk').checked ? '1' : '0'
            };
        }

        document.getElementById('addPhoneBtn').addEventListener('click', function () { clearModal(); modal.show(); });

        document.getElementById('savePhoneModalBtn').addEventListener('click', function () {
            var d = readModal();
            if (!d.number) { showValidationError('Phone number is required.'); return; }
            var items = getAllData();
            var editIdx = parseInt(document.getElementById('phoneEditIdx').value);
            if (editIdx >= 0) { items[editIdx] = d; } else { items.push(d); }
            rebuild(items);
            savePhonesToDatabase({ hideModalOnSuccess: true });
        });

        container.addEventListener('click', function (e) {
            var btn = e.target.closest('.edit-phone-btn');
            if (btn) { fillModal(parseInt(btn.dataset.idx)); modal.show(); return; }
            btn = e.target.closest('.remove-phone-btn');
            if (btn) {
                var items = getAllData();
                items.splice(parseInt(btn.dataset.idx), 1);
                rebuild(items);
                savePhonesToDatabase();
            }
        });

        function savePhonesToDatabase(options) {
            options = options || {};
            var items = getAllData();
            var body = new URLSearchParams();
            body.append('userID', document.getElementById('pageUserID').value);
            body.append('section', 'phones');
            body.append('count', items.length);
            var primaryIdx = -1;
            items.forEach(function (d, i) {
                body.append('number_' + i, d.number);
                body.append('type_' + i, d.type);
                if (d.primary === '1') primaryIdx = i;
            });
            body.append('primary_idx', primaryIdx);
            var status = getSaveStatusEl('savePhonesBtn', 'phonesSaveStatus');
            if (!status) return Promise.resolve({ success: false, message: 'Save status unavailable' });
            return ajaxSave('phones', body, status).then(function (data) {
                if (data && data.success && options.hideModalOnSuccess) {
                    modal.hide();
                }
                return data;
            });
        }

    })();

    /* ────────────────────────────────────────────────────────
       ALIAS SECTION
       ──────────────────────────────────────────────────────── */
    (function () {
        var container = document.getElementById('aliasesContainer');
        if (!container) return;
        var modalEl = document.getElementById('aliasModal');
        var modal = new bootstrap.Modal(modalEl);

        /* Populate alias type select from global vars set by CF */
        var typeSel = document.getElementById('aliasType');
        if (typeof aliasTypeOptions !== 'undefined') {
            for (var ti = 0; ti < aliasTypeOptions.length; ti++) {
                var opt = document.createElement('option');
                opt.value = aliasTypeOptions[ti];
                opt.textContent = aliasTypeLabels[ti];
                typeSel.appendChild(opt);
            }
        }

        function getAllData() {
            var items = [];
            var hiddens = container.querySelectorAll('input[data-alias-field="first"]');
            hiddens.forEach(function (el) {
                var idx = el.getAttribute('data-alias-idx');
                var get = function(f) { return (container.querySelector('input[data-alias-field="'+f+'"][data-alias-idx="'+idx+'"]') || {}).value || ''; };
                items.push({ first: el.value, middle: get('middle'), last: get('last'), type: get('type'), source: get('source'), active: get('active'), primary: get('primary') });
            });
            return items;
        }

        function ensureSinglePrimary(items, preferredIdx) {
            var idx = typeof preferredIdx === 'number' ? preferredIdx : -1;
            var i;

            if (idx < 0) {
                for (i = 0; i < items.length; i++) {
                    if (items[i].primary === '1') { idx = i; break; }
                }
            }
            if (idx < 0) {
                for (i = 0; i < items.length; i++) {
                    if (items[i].active === '1') { idx = i; break; }
                }
            }
            if (idx < 0 && items.length) {
                idx = 0;
            }

            for (i = 0; i < items.length; i++) {
                items[i].primary = (i === idx) ? '1' : '0';
            }
        }

        function rebuild(items) {
            ensureSinglePrimary(items);
            container.innerHTML = '';
            items.forEach(function (d, i) {
                var name = [d.first, d.middle, d.last].filter(Boolean).join(' ');
                container.insertAdjacentHTML('beforeend',
                    "<div class='card mb-2'><div class='card-body py-2 px-3'>" +
                    "<div class='d-flex justify-content-between align-items-center'><div>" +
                    "<strong>" + esc(name) + "</strong>" +
                    (d.type ? " <span class='badge bg-info text-dark'>" + esc(d.type) + "</span>" : "") +
                    (d.source ? " <small class='text-muted'>(" + esc(d.source) + ")</small>" : "") +
                    (d.primary === '1' ? " <span class='badge bg-success'>Primary</span>" : "") +
                    (d.active === '1' ? " <span class='badge bg-success'>Active</span>" : " <span class='badge bg-secondary text-dark'>Inactive</span>") +
                    "</div><div>" +
                    "<button type='button' class='btn btn-sm btn-outline-primary set-primary-alias-btn' data-idx='" + i + "'" + (d.primary === '1' ? " disabled" : "") + ">Set Primary</button> " +
                    "<button type='button' class='btn btn-sm btn-edit edit-alias-btn' data-idx='" + i + "'><i class='bi bi-pencil-square me-1'></i>Edit</button> " +
                    "<button type='button' class='btn btn-sm btn-remove remove-alias-btn' data-idx='" + i + "'><i class='bi bi-trash me-1'></i>Remove</button>" +
                    "</div></div></div></div>" +
                    "<input type='hidden' data-alias-field='first' data-alias-idx='" + i + "' value='" + esc(d.first) + "'>" +
                    "<input type='hidden' data-alias-field='middle' data-alias-idx='" + i + "' value='" + esc(d.middle) + "'>" +
                    "<input type='hidden' data-alias-field='last' data-alias-idx='" + i + "' value='" + esc(d.last) + "'>" +
                    "<input type='hidden' data-alias-field='type' data-alias-idx='" + i + "' value='" + esc(d.type) + "'>" +
                    "<input type='hidden' data-alias-field='source' data-alias-idx='" + i + "' value='" + esc(d.source) + "'>" +
                    "<input type='hidden' data-alias-field='active' data-alias-idx='" + i + "' value='" + (d.active || '0') + "'>" +
                    "<input type='hidden' data-alias-field='primary' data-alias-idx='" + i + "' value='" + (d.primary || '0') + "'>"
                );
            });
        }

        function clearModal() {
            document.getElementById('aliasEditIdx').value = '-1';
            document.getElementById('aliasFirst').value = '';
            document.getElementById('aliasMiddle').value = '';
            document.getElementById('aliasLast').value = '';
            document.getElementById('aliasType').value = '';
            document.getElementById('aliasSource').value = '';
            document.getElementById('aliasActive').checked = true;
            document.getElementById('aliasModalLabel').textContent = 'Add Alias';
        }

        function fillModal(idx) {
            var items = getAllData();
            var d = items[idx];
            document.getElementById('aliasEditIdx').value = idx;
            document.getElementById('aliasFirst').value = d.first;
            document.getElementById('aliasMiddle').value = d.middle;
            document.getElementById('aliasLast').value = d.last;
            document.getElementById('aliasType').value = d.type;
            document.getElementById('aliasSource').value = d.source;
            document.getElementById('aliasActive').checked = d.active === '1';
            document.getElementById('aliasModalLabel').textContent = 'Edit Alias';
        }

        function readModal() {
            return {
                first: document.getElementById('aliasFirst').value.trim(),
                middle: document.getElementById('aliasMiddle').value.trim(),
                last: document.getElementById('aliasLast').value.trim(),
                type: document.getElementById('aliasType').value,
                source: document.getElementById('aliasSource').value.trim(),
                active: document.getElementById('aliasActive').checked ? '1' : '0'
            };
        }

        document.getElementById('addAliasBtn').addEventListener('click', function () { clearModal(); modal.show(); });

        document.getElementById('saveAliasModalBtn').addEventListener('click', function () {
            var d = readModal();
            if (!d.first && !d.last) { showValidationError('First or Last name is required.'); return; }
            var items = getAllData();
            var editIdx = parseInt(document.getElementById('aliasEditIdx').value);
            var existingPrimary = '0';
            if (editIdx >= 0 && items[editIdx]) {
                existingPrimary = items[editIdx].primary || '0';
                d.primary = existingPrimary;
                items[editIdx] = d;
            } else {
                d.primary = items.length === 1 ? '1' : '0';
                items.push(d);
            }

            if (d.primary === '1' && d.active !== '1') {
                d.active = '1';
            }
            rebuild(items);
            saveAliasesToDatabase({ hideModalOnSuccess: true });
        });

        container.addEventListener('click', function (e) {
            var btn = e.target.closest('.edit-alias-btn');
            if (btn) { fillModal(parseInt(btn.dataset.idx)); modal.show(); return; }
            btn = e.target.closest('.set-primary-alias-btn');
            if (btn) {
                var items = getAllData();
                var idx = parseInt(btn.dataset.idx);
                if (!isNaN(idx) && items[idx]) {
                    items[idx].active = '1';
                    ensureSinglePrimary(items, idx);
                    rebuild(items);
                    saveAliasesToDatabase();
                }
                return;
            }
            btn = e.target.closest('.remove-alias-btn');
            if (btn) {
                var items = getAllData();
                items.splice(parseInt(btn.dataset.idx), 1);
                rebuild(items);
                saveAliasesToDatabase();
            }
        });

        function saveAliasesToDatabase(options) {
            options = options || {};
            var items = getAllData();
            ensureSinglePrimary(items);
            var body = new URLSearchParams();
            body.append('userID', document.getElementById('pageUserID').value);
            body.append('section', 'aliases');
            body.append('count', items.length);
            items.forEach(function (d, i) {
                body.append('first_' + i, d.first);
                body.append('middle_' + i, d.middle);
                body.append('last_' + i, d.last);
                body.append('type_' + i, d.type);
                body.append('source_' + i, d.source);
                body.append('active_' + i, d.active);
                body.append('primary_' + i, d.primary || '0');
            });
            var status = getSaveStatusEl('saveAliasesBtn', 'aliasesSaveStatus');
            if (!status) return Promise.resolve({ success: false, message: 'Save status unavailable' });
            return ajaxSave('aliases', body, status).then(function (data) {
                if (data && data.success && options.hideModalOnSuccess) {
                    modal.hide();
                }
                return data;
            });
        }

    })();

    /* ────────────────────────────────────────────────────────
       DEGREE SECTION (Bio tab)
       ──────────────────────────────────────────────────────── */
    (function () {
        var container = document.getElementById('degreesContainer');
        if (!container) return;
        var modalEl = document.getElementById('degreeModal');
        var modal = new bootstrap.Modal(modalEl);

        var degreeIsUhcoEl = document.getElementById('degreeIsUHCO');
        var degreeIsEnrolledEl = document.getElementById('degreeIsEnrolled');
        var degreeHasYearChangeEl = document.getElementById('degreeHasYearChange');
        var degreeUhcoFieldsEl = document.getElementById('degreeUhcoFields');
        var degreeExpectedGradYearEl = document.getElementById('degreeExpectedGradYear');
        var degreeOriginalExpectedGradYearEl = document.getElementById('degreeOriginalExpectedGradYear');

        function syncDegreeModalState() {
            if (!degreeIsUhcoEl || !degreeIsEnrolledEl || !degreeHasYearChangeEl) return;
            var isUhco = !!degreeIsUhcoEl.checked;
            var isEnrolled = !!degreeIsEnrolledEl.checked;
            var hasYearChange = !!degreeHasYearChangeEl.checked;

            if (degreeUhcoFieldsEl) {
                degreeUhcoFieldsEl.classList.toggle('d-none', !isUhco);
            }

            var programEl = document.getElementById('degreeProgram');
            if (programEl) {
                programEl.disabled = !isUhco;
                if (!isUhco) {
                    programEl.value = '';
                }
            }

            degreeIsEnrolledEl.disabled = !isUhco;
            if (!isUhco) {
                degreeIsEnrolledEl.checked = false;
                degreeHasYearChangeEl.checked = false;
            }

            degreeHasYearChangeEl.disabled = !isUhco || !degreeIsEnrolledEl.checked;
            if (degreeHasYearChangeEl.disabled) {
                degreeHasYearChangeEl.checked = false;
            }

            if (degreeExpectedGradYearEl) {
                degreeExpectedGradYearEl.disabled = !isUhco || !degreeIsEnrolledEl.checked;
                if (degreeExpectedGradYearEl.disabled) {
                    degreeExpectedGradYearEl.value = '';
                }
            }

            if (degreeOriginalExpectedGradYearEl) {
                degreeOriginalExpectedGradYearEl.disabled = !isUhco || !degreeHasYearChangeEl.checked;
                if (degreeOriginalExpectedGradYearEl.disabled) {
                    degreeOriginalExpectedGradYearEl.value = '';
                }
            }
        }

        function getAllData() {
            var items = [];
            var hiddens = container.querySelectorAll('input[data-degree-field="name"]');
            hiddens.forEach(function (el) {
                var idx = el.getAttribute('data-degree-idx');
                var get = function(f) { return (container.querySelector('input[data-degree-field="'+f+'"][data-degree-idx="'+idx+'"]') || {}).value || ''; };
                items.push({
                    name: el.value,
                    university: get('university'),
                    year: get('year'),
                    isuhco: get('isuhco') || '0',
                    isenrolled: get('isenrolled') || '0',
                    haschange: get('haschange') || '0',
                    origexpgrad: get('origexpgrad') || '',
                    expgrad: get('expgrad') || '',
                    program: get('program') || ''
                });
            });
            return items;
        }

        function rebuild(items) {
            container.innerHTML = '';
            items.forEach(function (d, i) {
                container.insertAdjacentHTML('beforeend',
                    "<div class='card mb-2'><div class='card-body py-2 px-3'>" +
                    "<div class='d-flex justify-content-between align-items-center'><div>" +
                    "<strong>" + esc(d.name) + "</strong>" +
                    (d.university ? " <small class='text-muted'>— " + esc(d.university) + "</small>" : "") +
                    (d.year ? " <small class='text-muted'>(" + esc(d.year) + ")</small>" : "") +
                    (d.isuhco === '1' ? " <span class='badge bg-primary ms-1'>UHCO</span>" : "") +
                    (d.program ? " <span class='badge bg-info text-dark ms-1'>" + esc(d.program) + "</span>" : "") +
                    "</div><div>" +
                    "<button type='button' class='btn btn-sm btn-edit edit-degree-btn' data-idx='" + i + "'><i class='bi bi-pencil-square me-1'></i>Edit</button> " +
                    "<button type='button' class='btn btn-sm btn-remove remove-degree-btn' data-idx='" + i + "'><i class='bi bi-trash me-1'></i>Remove</button>" +
                    "</div></div></div></div>" +
                    "<input type='hidden' data-degree-field='name' data-degree-idx='" + i + "' value='" + esc(d.name) + "'>" +
                    "<input type='hidden' data-degree-field='university' data-degree-idx='" + i + "' value='" + esc(d.university) + "'>" +
                    "<input type='hidden' data-degree-field='year' data-degree-idx='" + i + "' value='" + esc(d.year) + "'>" +
                    "<input type='hidden' data-degree-field='isuhco' data-degree-idx='" + i + "' value='" + esc(d.isuhco || '0') + "'>" +
                    "<input type='hidden' data-degree-field='isenrolled' data-degree-idx='" + i + "' value='" + esc(d.isenrolled || '0') + "'>" +
                    "<input type='hidden' data-degree-field='haschange' data-degree-idx='" + i + "' value='" + esc(d.haschange || '0') + "'>" +
                    "<input type='hidden' data-degree-field='origexpgrad' data-degree-idx='" + i + "' value='" + esc(d.origexpgrad || '') + "'>" +
                    "<input type='hidden' data-degree-field='expgrad' data-degree-idx='" + i + "' value='" + esc(d.expgrad || '') + "'>" +
                    "<input type='hidden' data-degree-field='program' data-degree-idx='" + i + "' value='" + esc(d.program || '') + "'>"
                );
            });
        }

        function clearModal() {
            document.getElementById('degreeEditIdx').value = '-1';
            document.getElementById('degreeName').value = '';
            document.getElementById('degreeUniversity').value = '';
            document.getElementById('degreeYear').value = '';
            document.getElementById('degreeProgram').value = '';
            if (degreeIsUhcoEl) degreeIsUhcoEl.checked = false;
            if (degreeIsEnrolledEl) degreeIsEnrolledEl.checked = false;
            if (degreeHasYearChangeEl) degreeHasYearChangeEl.checked = false;
            if (degreeExpectedGradYearEl) degreeExpectedGradYearEl.value = '';
            if (degreeOriginalExpectedGradYearEl) degreeOriginalExpectedGradYearEl.value = '';
            syncDegreeModalState();
            document.getElementById('degreeModalLabel').textContent = 'Add Degree';
        }

        function fillModal(idx) {
            var items = getAllData();
            var d = items[idx];
            document.getElementById('degreeEditIdx').value = idx;
            document.getElementById('degreeName').value = d.name;
            document.getElementById('degreeUniversity').value = d.university;
            document.getElementById('degreeYear').value = d.year;
            document.getElementById('degreeProgram').value = d.program || '';
            if (degreeIsUhcoEl) degreeIsUhcoEl.checked = (d.isuhco === '1');
            if (degreeIsEnrolledEl) degreeIsEnrolledEl.checked = (d.isenrolled === '1');
            if (degreeHasYearChangeEl) degreeHasYearChangeEl.checked = (d.haschange === '1');
            if (degreeExpectedGradYearEl) degreeExpectedGradYearEl.value = d.expgrad || '';
            if (degreeOriginalExpectedGradYearEl) degreeOriginalExpectedGradYearEl.value = d.origexpgrad || '';
            syncDegreeModalState();
            document.getElementById('degreeModalLabel').textContent = 'Edit Degree';
        }

        function readModal() {
            return {
                name: document.getElementById('degreeName').value.trim(),
                university: document.getElementById('degreeUniversity').value.trim(),
                year: document.getElementById('degreeYear').value.trim(),
                isuhco: degreeIsUhcoEl && degreeIsUhcoEl.checked ? '1' : '0',
                isenrolled: degreeIsEnrolledEl && degreeIsEnrolledEl.checked ? '1' : '0',
                haschange: degreeHasYearChangeEl && degreeHasYearChangeEl.checked ? '1' : '0',
                origexpgrad: degreeOriginalExpectedGradYearEl ? degreeOriginalExpectedGradYearEl.value.trim() : '',
                expgrad: degreeExpectedGradYearEl ? degreeExpectedGradYearEl.value.trim() : '',
                program: document.getElementById('degreeProgram').value
            };
        }

        if (degreeIsUhcoEl) {
            degreeIsUhcoEl.addEventListener('change', syncDegreeModalState);
        }
        if (degreeIsEnrolledEl) {
            degreeIsEnrolledEl.addEventListener('change', syncDegreeModalState);
        }
        if (degreeHasYearChangeEl) {
            degreeHasYearChangeEl.addEventListener('change', syncDegreeModalState);
        }

        var addDegreeBtn = document.getElementById('addDegreeBtn');
        if (addDegreeBtn) {
            addDegreeBtn.addEventListener('click', function () { clearModal(); modal.show(); });
        }

        document.getElementById('saveDegreeModalBtn').addEventListener('click', function () {
            var d = readModal();
            if (!d.name) { showValidationError('Degree name is required.'); return; }
            var items = getAllData();
            var editIdx = parseInt(document.getElementById('degreeEditIdx').value);
            if (editIdx >= 0) { items[editIdx] = d; } else { items.push(d); }
            rebuild(items);
            saveDegreesToDatabase({ hideModalOnSuccess: true });
        });

        container.addEventListener('click', function (e) {
            var btn = e.target.closest('.edit-degree-btn');
            if (btn) { fillModal(parseInt(btn.dataset.idx)); modal.show(); return; }
            btn = e.target.closest('.remove-degree-btn');
            if (btn) {
                var items = getAllData();
                items.splice(parseInt(btn.dataset.idx), 1);
                rebuild(items);
                saveDegreesToDatabase();
            }
        });

        function saveDegreesToDatabase(options) {
            options = options || {};
            var items = getAllData();
            var body = new URLSearchParams();
            body.append('userID', document.getElementById('pageUserID').value);
            body.append('section', 'degrees');
            body.append('count', items.length);
            items.forEach(function (d, i) {
                body.append('name_' + i, d.name);
                body.append('univ_' + i, d.university);
                body.append('year_' + i, d.year);
                body.append('isuhco_' + i, d.isuhco || '0');
                body.append('isenrolled_' + i, d.isenrolled || '0');
                body.append('haschange_' + i, d.haschange || '0');
                body.append('origexpgrad_' + i, d.origexpgrad || '');
                body.append('expgrad_' + i, d.expgrad || '');
                body.append('program_' + i, d.program || '');
            });
            var status = getSaveStatusEl('saveDegreesBtn', 'degreesSaveStatus');
            if (!status) return Promise.resolve({ success: false, message: 'Save status unavailable' });
            return ajaxSave('degrees', body, status, function (data) {
                /* Update composite degrees field if present */
                var comp = document.getElementById('bio_composite');
                if (comp && data.data && data.data.composite) comp.value = data.data.composite;
            }).then(function (data) {
                if (data && data.success && options.hideModalOnSuccess) {
                    modal.hide();
                }
                return data;
            });
        }

    })();

    /* ────────────────────────────────────────────────────────
       AWARD SECTION
       ──────────────────────────────────────────────────────── */
    (function () {
        var container = document.getElementById('awardsContainer');
        if (!container) return;
        var modalEl = document.getElementById('awardModal');
        var modal = new bootstrap.Modal(modalEl);

        var awardSel = document.getElementById('awardSelect');
        var otherWrap = document.getElementById('awardOtherWrap');
        awardSel.addEventListener('change', function () {
            if (awardSel.value === 'Other') { otherWrap.classList.remove('d-none'); } else { otherWrap.classList.add('d-none'); document.getElementById('awardOtherInput').value = ''; }
            /* Auto-set type for predefined honors */
            if (typeof honorsSet !== 'undefined' && honorsSet[awardSel.value]) { document.getElementById('awardType').value = 'Honor'; }
        });

        function getAllData() {
            var items = [];
            var hiddens = container.querySelectorAll('input[data-award-field="name"]');
            hiddens.forEach(function (el) {
                var idx = el.getAttribute('data-award-idx');
                var get = function(f) { return (container.querySelector('input[data-award-field="'+f+'"][data-award-idx="'+idx+'"]') || {}).value || ''; };
                items.push({ name: el.value, type: get('type') });
            });
            return items;
        }

        function rebuild(items) {
            container.innerHTML = '';
            items.forEach(function (d, i) {
                container.insertAdjacentHTML('beforeend',
                    "<div class='card mb-2'><div class='card-body py-2 px-3'>" +
                    "<div class='d-flex justify-content-between align-items-center'><div>" +
                    "<strong>" + esc(d.name) + "</strong>" +
                    (d.type ? " <span class='badge bg-info text-dark'>" + esc(d.type) + "</span>" : "") +
                    "</div><div>" +
                    "<button type='button' class='btn btn-sm btn-edit edit-award-btn' data-idx='" + i + "'><i class='bi bi-pencil-square me-1'></i>Edit</button> " +
                    "<button type='button' class='btn btn-sm btn-remove remove-award-btn' data-idx='" + i + "'><i class='bi bi-trash me-1'></i>Remove</button>" +
                    "</div></div></div></div>" +
                    "<input type='hidden' data-award-field='name' data-award-idx='" + i + "' value='" + esc(d.name) + "'>" +
                    "<input type='hidden' data-award-field='type' data-award-idx='" + i + "' value='" + esc(d.type) + "'>"
                );
            });
        }

        function clearModal() {
            document.getElementById('awardEditIdx').value = '-1';
            document.getElementById('awardSelect').value = '';
            document.getElementById('awardOtherInput').value = '';
            otherWrap.classList.add('d-none');
            document.getElementById('awardType').value = '';
            document.getElementById('awardModalLabel').textContent = 'Add Award';
        }

        function fillModal(idx) {
            var items = getAllData();
            var d = items[idx];
            document.getElementById('awardEditIdx').value = idx;
            /* Check if name matches a predefined option */
            var opts = awardSel.options;
            var found = false;
            for (var oi = 0; oi < opts.length; oi++) {
                if (opts[oi].value === d.name) { found = true; break; }
            }
            if (found) {
                awardSel.value = d.name;
                otherWrap.classList.add('d-none');
            } else {
                awardSel.value = 'Other';
                otherWrap.classList.remove('d-none');
                document.getElementById('awardOtherInput').value = d.name;
            }
            document.getElementById('awardType').value = d.type;
            document.getElementById('awardModalLabel').textContent = 'Edit Award';
        }

        function readModal() {
            var name = awardSel.value === 'Other' ? document.getElementById('awardOtherInput').value.trim() : awardSel.value;
            return { name: name, type: document.getElementById('awardType').value };
        }

        var addAwardBtn = document.getElementById('addAwardBtn');
        if (addAwardBtn) {
            addAwardBtn.addEventListener('click', function () { clearModal(); modal.show(); });
        }

        document.getElementById('saveAwardModalBtn').addEventListener('click', function () {
            var d = readModal();
            if (!d.name) { showValidationError('Award name is required.'); return; }
            var items = getAllData();
            var editIdx = parseInt(document.getElementById('awardEditIdx').value);
            if (editIdx >= 0) { items[editIdx] = d; } else { items.push(d); }
            rebuild(items);
            saveAwardsToDatabase({ hideModalOnSuccess: true });
        });

        container.addEventListener('click', function (e) {
            var btn = e.target.closest('.edit-award-btn');
            if (btn) { fillModal(parseInt(btn.dataset.idx)); modal.show(); return; }
            btn = e.target.closest('.remove-award-btn');
            if (btn) {
                var items = getAllData();
                items.splice(parseInt(btn.dataset.idx), 1);
                rebuild(items);
                saveAwardsToDatabase();
            }
        });

        function saveAwardsToDatabase(options) {
            options = options || {};
            var items = getAllData();
            var body = new URLSearchParams();
            body.append('userID', document.getElementById('pageUserID').value);
            body.append('section', 'awards');
            body.append('count', items.length);
            items.forEach(function (d, i) {
                body.append('name_' + i, d.name);
                body.append('type_' + i, d.type);
            });
            var status = getSaveStatusEl('saveAwardsBtn', 'awardsSaveStatus');
            if (!status) return Promise.resolve({ success: false, message: 'Save status unavailable' });
            return ajaxSave('awards', body, status).then(function (data) {
                if (data && data.success && options.hideModalOnSuccess) {
                    modal.hide();
                }
                return data;
            });
        }

    })();

    /* ────────────────────────────────────────────────────────
       RESIDENCY SECTION
       ──────────────────────────────────────────────────────── */
    (function () {
        var container = document.getElementById('residenciesContainer');
        if (!container) return;
        var modalEl = document.getElementById('residencyModal');
        var modal = new bootstrap.Modal(modalEl);

        function getAllData() {
            var items = [];
            var hiddens = container.querySelectorAll('input[data-residency-field="location"]');
            hiddens.forEach(function (el) {
                var idx = el.getAttribute('data-residency-idx');
                var get = function (f) { return (container.querySelector('input[data-residency-field="' + f + '"][data-residency-idx="' + idx + '"]') || {}).value || ''; };
                items.push({
                    location: el.value,
                    specialty: get('specialty'),
                    startingyear: get('startingyear'),
                    isuhco: get('isuhco') || '0',
                    iscurrent: get('iscurrent') || '0'
                });
            });
            return items;
        }

        function rebuild(items) {
            container.innerHTML = '';
            items.forEach(function (d, i) {
                container.insertAdjacentHTML('beforeend',
                    "<div class='card mb-2'><div class='card-body py-2 px-3'>" +
                    "<div class='d-flex justify-content-between align-items-center'><div>" +
                    "<strong>" + esc(d.location) + "</strong>" +
                    (d.specialty ? " <span class='text-muted'>- " + esc(d.specialty) + "</span>" : "") +
                    (d.startingyear ? " <span class='badge bg-secondary text-dark ms-1'>" + esc(d.startingyear) + "</span>" : "") +
                    (d.isuhco === '1' ? " <span class='badge bg-primary ms-1'>UHCO</span>" : "") +
                    (d.iscurrent === '1' ? " <span class='badge bg-success ms-1'>Current</span>" : "") +
                    "</div><div>" +
                    "<button type='button' class='btn btn-sm btn-edit edit-residency-btn' data-idx='" + i + "'><i class='bi bi-pencil-square me-1'></i>Edit</button> " +
                    "<button type='button' class='btn btn-sm btn-remove remove-residency-btn' data-idx='" + i + "'><i class='bi bi-trash me-1'></i>Remove</button>" +
                    "</div></div></div></div>" +
                    "<input type='hidden' data-residency-field='location' data-residency-idx='" + i + "' value='" + esc(d.location) + "'>" +
                    "<input type='hidden' data-residency-field='specialty' data-residency-idx='" + i + "' value='" + esc(d.specialty) + "'>" +
                    "<input type='hidden' data-residency-field='startingyear' data-residency-idx='" + i + "' value='" + esc(d.startingyear) + "'>" +
                    "<input type='hidden' data-residency-field='isuhco' data-residency-idx='" + i + "' value='" + (d.isuhco || '0') + "'>" +
                    "<input type='hidden' data-residency-field='iscurrent' data-residency-idx='" + i + "' value='" + (d.iscurrent || '0') + "'>"
                );
            });
        }

        function clearModal() {
            document.getElementById('residencyEditIdx').value = '-1';
            document.getElementById('residencyLocation').value = '';
            document.getElementById('residencySpecialty').value = '';
            document.getElementById('residencyStartingYear').value = '';
            document.getElementById('residencyIsUHCO').checked = false;
            document.getElementById('residencyIsCurrent').checked = false;
            document.getElementById('residencyModalLabel').textContent = 'Add Residency';
        }

        function fillModal(idx) {
            var items = getAllData();
            var d = items[idx];
            document.getElementById('residencyEditIdx').value = idx;
            document.getElementById('residencyLocation').value = d.location;
            document.getElementById('residencySpecialty').value = d.specialty;
            document.getElementById('residencyStartingYear').value = d.startingyear;
            document.getElementById('residencyIsUHCO').checked = d.isuhco === '1';
            document.getElementById('residencyIsCurrent').checked = d.iscurrent === '1';
            document.getElementById('residencyModalLabel').textContent = 'Edit Residency';
        }

        function readModal() {
            return {
                location: document.getElementById('residencyLocation').value.trim(),
                specialty: document.getElementById('residencySpecialty').value.trim(),
                startingyear: document.getElementById('residencyStartingYear').value.trim(),
                isuhco: document.getElementById('residencyIsUHCO').checked ? '1' : '0',
                iscurrent: document.getElementById('residencyIsCurrent').checked ? '1' : '0'
            };
        }

        var addResidencyBtn = document.getElementById('addResidencyBtn');
        if (addResidencyBtn) {
            addResidencyBtn.addEventListener('click', function () { clearModal(); modal.show(); });
        }

        document.getElementById('saveResidencyModalBtn').addEventListener('click', function () {
            var d = readModal();
            if (!d.location) { showValidationError('Residency location is required.'); return; }
            var items = getAllData();
            var editIdx = parseInt(document.getElementById('residencyEditIdx').value, 10);
            if (editIdx >= 0) { items[editIdx] = d; } else { items.push(d); }
            rebuild(items);
            saveResidenciesToDatabase({ hideModalOnSuccess: true });
        });

        container.addEventListener('click', function (e) {
            var btn = e.target.closest('.edit-residency-btn');
            if (btn) { fillModal(parseInt(btn.dataset.idx, 10)); modal.show(); return; }
            btn = e.target.closest('.remove-residency-btn');
            if (btn) {
                var items = getAllData();
                items.splice(parseInt(btn.dataset.idx, 10), 1);
                rebuild(items);
                saveResidenciesToDatabase();
            }
        });

        function saveResidenciesToDatabase(options) {
            options = options || {};
            var items = getAllData();
            var body = new URLSearchParams();
            body.append('userID', document.getElementById('pageUserID').value);
            body.append('section', 'residencies');
            body.append('count', items.length);
            items.forEach(function (d, i) {
                body.append('location_' + i, d.location);
                body.append('specialty_' + i, d.specialty);
                body.append('startingyear_' + i, d.startingyear);
                body.append('isuhco_' + i, d.isuhco || '0');
                body.append('iscurrent_' + i, d.iscurrent || '0');
            });
            var status = getSaveStatusEl('saveResidenciesBtn', 'residenciesSaveStatus');
            if (!status) return Promise.resolve({ success: false, message: 'Save status unavailable' });
            return ajaxSave('residencies', body, status).then(function (data) {
                if (data && data.success && options.hideModalOnSuccess) {
                    modal.hide();
                }
                return data;
            });
        }

    })();

    /* ────────────────────────────────────────────────────────
       ADDRESS SECTION
       ──────────────────────────────────────────────────────── */
    (function () {
        var container = document.getElementById('addressesContainer');
        if (!container) return;
        var modalEl = document.getElementById('addressModal');
        var modal = new bootstrap.Modal(modalEl);

        function getAllData() {
            var items = [];
            var hiddens = container.querySelectorAll('input[data-addr-field="type"]');
            hiddens.forEach(function (el) {
                var idx = el.getAttribute('data-addr-idx');
                var get = function(f) { return (container.querySelector('input[data-addr-field="'+f+'"][data-addr-idx="'+idx+'"]') || {}).value || ''; };
                items.push({ type: el.value, addr1: get('addr1'), addr2: get('addr2'), city: get('city'),
                             state: get('state'), zip: get('zip'), building: get('building'), room: get('room'),
                             mailcode: get('mailcode'), primary: get('primary') });
            });
            return items;
        }

        function rebuild(items) {
            container.innerHTML = '';
            items.forEach(function (d, i) {
                var loc = [];
                if (d.addr1) loc.push(esc(d.addr1));
                if (d.addr2) loc.push(esc(d.addr2));
                var csz = [];
                if (d.city) csz.push(d.city);
                if (d.state) csz.push(d.state);
                var cszStr = csz.join(', ');
                if (d.zip) cszStr += ' ' + d.zip;
                if (cszStr) loc.push(esc(cszStr));
                var extras = [];
                if (d.building) extras.push('Bldg: ' + esc(d.building));
                if (d.room) extras.push('Rm: ' + esc(d.room));
                if (d.mailcode) extras.push('MC: ' + esc(d.mailcode));
                if (extras.length) loc.push(extras.join(' | '));

                container.insertAdjacentHTML('beforeend',
                    "<div class='card mb-2'><div class='card-body py-2 px-3'>" +
                    "<div class='d-flex justify-content-between align-items-start'><div>" +
                    "<strong>" + esc(d.type || '') + "</strong>" +
                    (d.primary === '1' ? " <span class='badge bg-success'>Primary</span>" : "") +
                    "<br><small class='text-muted'>" + loc.join('<br>') + "</small>" +
                    "</div><div>" +
                    "<button type='button' class='btn btn-sm btn-edit edit-address-btn' data-idx='" + i + "'><i class='bi bi-pencil-square me-1'></i>Edit</button> " +
                    "<button type='button' class='btn btn-sm btn-remove remove-address-btn' data-idx='" + i + "'><i class='bi bi-trash me-1'></i>Remove</button>" +
                    "</div></div></div></div>" +
                    "<input type='hidden' data-addr-field='type' data-addr-idx='" + i + "' value='" + esc(d.type) + "'>" +
                    "<input type='hidden' data-addr-field='addr1' data-addr-idx='" + i + "' value='" + esc(d.addr1) + "'>" +
                    "<input type='hidden' data-addr-field='addr2' data-addr-idx='" + i + "' value='" + esc(d.addr2) + "'>" +
                    "<input type='hidden' data-addr-field='city' data-addr-idx='" + i + "' value='" + esc(d.city) + "'>" +
                    "<input type='hidden' data-addr-field='state' data-addr-idx='" + i + "' value='" + esc(d.state) + "'>" +
                    "<input type='hidden' data-addr-field='zip' data-addr-idx='" + i + "' value='" + esc(d.zip) + "'>" +
                    "<input type='hidden' data-addr-field='building' data-addr-idx='" + i + "' value='" + esc(d.building) + "'>" +
                    "<input type='hidden' data-addr-field='room' data-addr-idx='" + i + "' value='" + esc(d.room) + "'>" +
                    "<input type='hidden' data-addr-field='mailcode' data-addr-idx='" + i + "' value='" + esc(d.mailcode) + "'>" +
                    "<input type='hidden' data-addr-field='primary' data-addr-idx='" + i + "' value='" + (d.primary || '0') + "'>"
                );
            });
        }

        function clearModal() {
            document.getElementById('addrEditIdx').value = '-1';
            document.getElementById('addrType').value = '';
            document.getElementById('addrAddr1').value = '';
            document.getElementById('addrAddr2').value = '';
            document.getElementById('addrCity').value = '';
            document.getElementById('addrState').value = '';
            document.getElementById('addrZip').value = '';
            document.getElementById('addrBuilding').value = '';
            document.getElementById('addrRoom').value = '';
            document.getElementById('addrMailcode').value = '';
            document.getElementById('addrPrimary').checked = false;
            document.getElementById('addressModalLabel').textContent = 'Add Address';
        }

        function fillModal(idx) {
            var items = getAllData();
            var d = items[idx];
            document.getElementById('addrEditIdx').value = idx;
            document.getElementById('addrType').value = d.type;
            document.getElementById('addrAddr1').value = d.addr1;
            document.getElementById('addrAddr2').value = d.addr2;
            document.getElementById('addrCity').value = d.city;
            document.getElementById('addrState').value = d.state;
            document.getElementById('addrZip').value = d.zip;
            document.getElementById('addrBuilding').value = d.building;
            document.getElementById('addrRoom').value = d.room;
            document.getElementById('addrMailcode').value = d.mailcode;
            document.getElementById('addrPrimary').checked = d.primary === '1';
            document.getElementById('addressModalLabel').textContent = 'Edit Address';
        }

        function readModal() {
            return {
                type: document.getElementById('addrType').value,
                addr1: document.getElementById('addrAddr1').value.trim(),
                addr2: document.getElementById('addrAddr2').value.trim(),
                city: document.getElementById('addrCity').value.trim(),
                state: document.getElementById('addrState').value.trim(),
                zip: document.getElementById('addrZip').value.trim(),
                building: document.getElementById('addrBuilding').value.trim(),
                room: document.getElementById('addrRoom').value.trim(),
                mailcode: document.getElementById('addrMailcode').value.trim(),
                primary: document.getElementById('addrPrimary').checked ? '1' : '0'
            };
        }

        /* Expose helpers so the "Copy to Addresses" button on the UH tab can inject a parsed address */
        container._addrGetAllData = getAllData;
        container._addrRebuild = rebuild;

        document.getElementById('addAddressBtn').addEventListener('click', function () { clearModal(); modal.show(); });

        document.getElementById('saveAddressBtn').addEventListener('click', function () {
            var d = readModal();
            if (!d.type) { showValidationError('Address Type is required.'); return; }
            var items = getAllData();
            var editIdx = parseInt(document.getElementById('addrEditIdx').value);
            if (editIdx >= 0) { items[editIdx] = d; } else { items.push(d); }
            rebuild(items);
            saveAddressesToDatabase({ hideModalOnSuccess: true });
        });

        container.addEventListener('click', function (e) {
            var btn = e.target.closest('.edit-address-btn');
            if (btn) { fillModal(parseInt(btn.dataset.idx)); modal.show(); return; }
            btn = e.target.closest('.remove-address-btn');
            if (btn) {
                var items = getAllData();
                items.splice(parseInt(btn.dataset.idx), 1);
                rebuild(items);
                saveAddressesToDatabase();
            }
        });

        function saveAddressesToDatabase(options) {
            options = options || {};
            var items = getAllData();
            var body = new URLSearchParams();
            body.append('userID', document.getElementById('pageUserID').value);
            body.append('section', 'addresses');
            body.append('count', items.length);
            items.forEach(function (d, i) {
                body.append('type_' + i, d.type);
                body.append('addr1_' + i, d.addr1);
                body.append('addr2_' + i, d.addr2);
                body.append('city_' + i, d.city);
                body.append('state_' + i, d.state);
                body.append('zip_' + i, d.zip);
                body.append('building_' + i, d.building);
                body.append('room_' + i, d.room);
                body.append('mailcode_' + i, d.mailcode);
                body.append('primary_' + i, d.primary);
            });
            var status = getSaveStatusEl('saveAddressesBtn', 'addressesSaveStatus');
            if (!status) return Promise.resolve({ success: false, message: 'Save status unavailable' });
            return ajaxSave('addresses', body, status).then(function (data) {
                if (data && data.success && options.hideModalOnSuccess) {
                    modal.hide();
                }
                return data;
            });
        }

    })();

    /* ══════════════════════════════════════════════════════════════
       Per-Tab AJAX Save Handlers
       ══════════════════════════════════════════════════════════════ */

    function saveSectionAjax(section, body, statusEl, onSuccess) {
        if (statusEl) {
            statusEl.textContent = 'Saving...';
            statusEl.classList.remove('text-danger', 'text-success');
            statusEl.classList.add('text-muted');
        }
        fetch('/admin/users/saveSection.cfm', { method: 'POST', body: body })
            .then(function (r) { return r.json(); })
            .then(function (data) {
                if (data.success) {
                    if (statusEl) {
                        statusEl.textContent = data.message || 'Saved.';
                        statusEl.classList.remove('text-muted', 'text-danger');
                        statusEl.classList.add('text-success');
                    }
                    showSaveToast('Saved successfully.');
                    clearDirty(section);
                    if (onSuccess) {
                        onSuccess(data);
                    }
                } else {
                    if (statusEl) {
                        statusEl.textContent = data.message || 'Error saving.';
                        statusEl.classList.remove('text-muted', 'text-success');
                        statusEl.classList.add('text-danger');
                    }
                    showSaveToast((data.message || 'Error saving.'), true);
                }
            })
            .catch(function (err) {
                if (statusEl) {
                    statusEl.textContent = 'Network error.';
                    statusEl.classList.remove('text-muted', 'text-success');
                    statusEl.classList.add('text-danger');
                }
                showSaveToast('Network error: ' + (err && err.message ? err.message : 'Unknown'), true);
            });
    }

    var pageUserID = document.getElementById('pageUserID').value;

    initUsersEditPageChrome();
    initRefreshPageButton();
    initDataQualityPanelToggle();
    initFlagDrivenTabVisibility();
    initFlagCardToggle();
    initDegreePanels();
    initRecordStatusToggle();
    initEmailPrimaryValidation();
    initOrgRoleModal();
    initBioEditor();

    wireSectionDirty('general', document.getElementById('general-pane'));
    wireSectionDirty('flags', document.getElementById('flags-pane'));
    wireSectionDirty('orgs', document.getElementById('orgs-pane'));
    wireSectionDirty('extids', document.getElementById('extids-pane'));
    wireSectionDirty('publications', document.getElementById('publications-pane'));
    wireSectionDirty('uh', document.getElementById('admin-pane'));
    wireSectionDirty('bioinfo', document.getElementById('bio-info-pane'));

    wireRepeaterDirty('emails', document.getElementById('emailsContainer'));
    wireRepeaterDirty('phones', document.getElementById('phonesContainer'));
    wireRepeaterDirty('aliases', document.getElementById('aliasesContainer'));
    wireRepeaterDirty('addresses', document.getElementById('addressesContainer'));
    wireRepeaterDirty('degrees', document.getElementById('degreesContainer'));
    wireRepeaterDirty('awards', document.getElementById('awardsContainer'));
    wireRepeaterDirty('residencies', document.getElementById('residenciesContainer'));

    window.addEventListener('users-edit-tab-selected', function (event) {
        var tabId = event && event.detail ? (event.detail.tabId || '') : '';
        if (!tabId) return;
        refreshTabData(tabId);
    });

    var refreshGeneralInfoBtn = document.getElementById('refreshGeneralInfoBtn');
    if (refreshGeneralInfoBtn) {
        refreshGeneralInfoBtn.addEventListener('click', function () {
            refreshTabData('general-tab');
        });
    }

    var refreshContactInfoBtn = document.getElementById('refreshContactInfoBtn');
    if (refreshContactInfoBtn) {
        refreshContactInfoBtn.addEventListener('click', function () {
            refreshTabData('contact-tab');
        });
    }

    var refreshBiographicalInfoBtn = document.getElementById('refreshBiographicalInfoBtn');
    if (refreshBiographicalInfoBtn) {
        refreshBiographicalInfoBtn.addEventListener('click', function () {
            refreshTabData('bio-info-tab');
        });
    }

    var refreshFlagsBtn = document.getElementById('refreshFlagsBtn');
    if (refreshFlagsBtn) {
        refreshFlagsBtn.addEventListener('click', function () {
            refreshTabData('flags-tab');
        });
    }

    var refreshOrgsBtn = document.getElementById('refreshOrgsBtn');
    if (refreshOrgsBtn) {
        refreshOrgsBtn.addEventListener('click', function () {
            refreshTabData('orgs-tab');
        });
    }

    var refreshExtidsBtn = document.getElementById('refreshExtidsBtn');
    if (refreshExtidsBtn) {
        refreshExtidsBtn.addEventListener('click', function () {
            refreshTabData('extids-tab');
        });
    }

    var refreshUhBtn = document.getElementById('refreshUhBtn');
    if (refreshUhBtn) {
        refreshUhBtn.addEventListener('click', function () {
            refreshTabData('admin-tab');
        });
    }

    /* ── Contact tab bulk save ── */
    var saveContactBtn = document.getElementById('save-contact-btn');
    if (saveContactBtn) {
        saveContactBtn.addEventListener('click', function () {
            var status = document.getElementById('save-contact-status');
            var emailPane = document.getElementById('contact-pane');
            if (!emailPane) {
                return;
            }

            function postSection(body) {
                return fetch('/admin/users/saveSection.cfm', {
                    method: 'POST',
                    body: body
                }).then(function (r) { return r.json(); });
            }

            function buildEmailsBody() {
                var body = new URLSearchParams();
                var items = [];
                var hiddens = emailPane.querySelectorAll('#emailsContainer input[data-email-field="addr"]');
                hiddens.forEach(function (el) {
                    var idx = el.getAttribute('data-email-idx');
                    var get = function (f) {
                        var target = emailPane.querySelector('#emailsContainer input[data-email-field="' + f + '"][data-email-idx="' + idx + '"]');
                        return target ? target.value : '';
                    };
                    items.push({ addr: el.value, type: get('type'), primary: get('primary') });
                });
                body.append('userID', pageUserID);
                body.append('section', 'emails');
                body.append('count', items.length);
                var primaryIdx = -1;
                items.forEach(function (d, i) {
                    body.append('address_' + i, d.addr || '');
                    body.append('type_' + i, d.type || '');
                    if ((d.primary || '0') === '1') {
                        primaryIdx = i;
                    }
                });
                body.append('primary_idx', primaryIdx);
                return body;
            }

            function buildPhonesBody() {
                var body = new URLSearchParams();
                var items = [];
                var hiddens = emailPane.querySelectorAll('#phonesContainer input[data-phone-field="number"]');
                hiddens.forEach(function (el) {
                    var idx = el.getAttribute('data-phone-idx');
                    var get = function (f) {
                        var target = emailPane.querySelector('#phonesContainer input[data-phone-field="' + f + '"][data-phone-idx="' + idx + '"]');
                        return target ? target.value : '';
                    };
                    items.push({ number: el.value, type: get('type'), primary: get('primary') });
                });
                body.append('userID', pageUserID);
                body.append('section', 'phones');
                body.append('count', items.length);
                var primaryIdx = -1;
                items.forEach(function (d, i) {
                    body.append('number_' + i, d.number || '');
                    body.append('type_' + i, d.type || '');
                    if ((d.primary || '0') === '1') {
                        primaryIdx = i;
                    }
                });
                body.append('primary_idx', primaryIdx);
                return body;
            }

            function buildAddressesBody() {
                var body = new URLSearchParams();
                var items = [];
                var hiddens = emailPane.querySelectorAll('#addressesContainer input[data-addr-field="type"]');
                hiddens.forEach(function (el) {
                    var idx = el.getAttribute('data-addr-idx');
                    var get = function (f) {
                        var target = emailPane.querySelector('#addressesContainer input[data-addr-field="' + f + '"][data-addr-idx="' + idx + '"]');
                        return target ? target.value : '';
                    };
                    items.push({
                        type: el.value,
                        addr1: get('addr1'),
                        addr2: get('addr2'),
                        city: get('city'),
                        state: get('state'),
                        zip: get('zip'),
                        building: get('building'),
                        room: get('room'),
                        mailcode: get('mailcode'),
                        primary: get('primary')
                    });
                });
                body.append('userID', pageUserID);
                body.append('section', 'addresses');
                body.append('count', items.length);
                items.forEach(function (d, i) {
                    body.append('type_' + i, d.type || '');
                    body.append('addr1_' + i, d.addr1 || '');
                    body.append('addr2_' + i, d.addr2 || '');
                    body.append('city_' + i, d.city || '');
                    body.append('state_' + i, d.state || '');
                    body.append('zip_' + i, d.zip || '');
                    body.append('building_' + i, d.building || '');
                    body.append('room_' + i, d.room || '');
                    body.append('mailcode_' + i, d.mailcode || '');
                    body.append('primary_' + i, d.primary || '0');
                });
                return body;
            }

            saveContactBtn.disabled = true;
            if (status) {
                status.textContent = 'Saving...';
                status.style.color = '#666';
            }

            Promise.all([
                postSection(buildEmailsBody()),
                postSection(buildPhonesBody()),
                postSection(buildAddressesBody())
            ]).then(function (results) {
                var ok = results.every(function (r) { return r && r.success; });
                showSaveToast(ok ? 'Contact info saved.' : 'Some sections failed to save.', !ok);
                if (ok) {
                    clearDirty('emails');
                    clearDirty('phones');
                    clearDirty('addresses');
                }
            }).catch(function () {
                showSaveToast('Network error saving contact info.', true);
            }).finally(function () {
                saveContactBtn.disabled = false;
            });
        });
    }

    /* ── General tab ── */
    var saveGeneralBtn = document.getElementById('save-general-btn');
    if (saveGeneralBtn) {
        saveGeneralBtn.addEventListener('click', function () {
            var pane = document.getElementById('general-pane');
            var body = new URLSearchParams();
            body.append('userID', pageUserID);
            body.append('section', 'general');
            ['Prefix','Suffix','Pronouns','FirstName','MiddleName','LastName','Title1','Title2','Title3'].forEach(function (f) {
                var el = pane.querySelector('[name="' + f + '"]');
                body.append(f, el ? el.value : '');
            });
            saveSectionAjax('general', body, document.getElementById('save-general-status'));
        });
    }

    /* ── Flags tab ── */
    var saveFlagsBtn = document.getElementById('save-flags-btn');
    if (saveFlagsBtn) {
        saveFlagsBtn.addEventListener('click', function () {
            var pane = document.getElementById('flags-pane');
            var checked = pane.querySelectorAll('input[name="Flags"]:checked');
            var ids = [];
            checked.forEach(function (cb) { ids.push(cb.value); });
            var body = new URLSearchParams();
            body.append('userID', pageUserID);
            body.append('section', 'flags');
            body.append('flagIDs', ids.join(','));
            saveSectionAjax('flags', body, document.getElementById('save-flags-status'), function () {
                var shouldShowDegreesAwards = shouldShowDegreesAwardsFromFlagsPane();
                var shouldShowFacultyBio = shouldShowFacultyBioFromFlagsPane();

                syncBiographicalDegreesAwardsVisibility(shouldShowDegreesAwards);
                syncBiographicalFacultyVisibility(shouldShowFacultyBio);

                if (shouldShowDegreesAwards) {
                    refreshTabData('bio-info-tab');
                }
            });
        });
    }

    /* ── Organizations tab ── */
    var saveOrgsBtn = document.getElementById('save-orgs-btn');
    if (saveOrgsBtn) {
        saveOrgsBtn.addEventListener('click', function () {
            var pane = document.getElementById('orgs-pane');
            var checked = pane.querySelectorAll('input[name="Organizations"]:checked');
            var ids = [];
            checked.forEach(function (cb) { ids.push(cb.value); });
            var body = new URLSearchParams();
            body.append('userID', pageUserID);
            body.append('section', 'orgs');
            body.append('orgIDs', ids.join(','));
            checked.forEach(function (cb) {
                var orgID = cb.value;
                var titleEl = pane.querySelector('[name="roleTitle_' + orgID + '"]');
                var orderEl = pane.querySelector('[name="roleOrder_' + orgID + '"]');
                body.append('roleTitle_' + orgID, titleEl ? titleEl.value : '');
                body.append('roleOrder_' + orgID, orderEl ? orderEl.value : '0');
            });
            saveSectionAjax('orgs', body, document.getElementById('save-orgs-status'));
        });
    }

    /* ── External IDs tab ── */
    function escHtml(str) {
        return String(str || '')
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/\"/g, '&quot;')
            .replace(/'/g, '&#39;');
    }

    var extidsLdapModalEl = document.getElementById('extidsLdapModal');
    var extidsLdapModal = extidsLdapModalEl ? new bootstrap.Modal(extidsLdapModalEl) : null;
    var extidsLdapRows = [];
    var extidsLdapStatusEl = document.getElementById('extids-ldap-status');
    var extidsLdapResultsBody = document.getElementById('extidsLdapResultsBody');

    function setExtidsLdapStatus(text, isError) {
        if (!extidsLdapStatusEl) {
            return;
        }
        extidsLdapStatusEl.textContent = text || '';
        extidsLdapStatusEl.classList.toggle('text-danger', !!isError);
        extidsLdapStatusEl.classList.toggle('text-muted', !isError);
    }

    function renderExtidsLdapRows(rows) {
        if (!extidsLdapResultsBody) {
            return;
        }
        if (!rows || !rows.length) {
            extidsLdapResultsBody.innerHTML = '<tr><td colspan="5" class="text-muted p-3">No matches found.</td></tr>';
            return;
        }

        extidsLdapResultsBody.innerHTML = rows.map(function (row, idx) {
            return '' +
                '<tr>' +
                    '<td>' + escHtml(row.displayName) + '</td>' +
                    '<td><code>' + escHtml(row.samAccountName) + '</code></td>' +
                    '<td>' + escHtml(row.employeeID) + '</td>' +
                    '<td>' + escHtml(row.mail) + '</td>' +
                    '<td class="text-end"><button type="button" class="btn btn-sm btn-outline-primary js-extids-ldap-select" data-idx="' + idx + '">Use</button></td>' +
                '</tr>';
        }).join('');
    }

    function normalizeLdapRow(row) {
        row = row || {};
        return {
            displayName: row.displayName || row.displayname || row.DISPLAYNAME || '',
            samAccountName: row.samAccountName || row.samaccountname || row.SAMACCOUNTNAME || '',
            employeeID: row.employeeID || row.employeeid || row.EMPLOYEEID || '',
            mail: row.mail || row.MAIL || '',
            department: row.department || row.DEPARTMENT || '',
            title: row.title || row.TITLE || ''
        };
    }

    // Read alias objects from the hidden inputs stamped into the DOM by ColdFusion.
    function readAliasesFromDOM() {
        var aliases = {};
        document.querySelectorAll('[data-alias-field][data-alias-idx]').forEach(function (el) {
            var idx = el.getAttribute('data-alias-idx');
            var field = el.getAttribute('data-alias-field');
            if (!aliases[idx]) { aliases[idx] = {}; }
            aliases[idx][field] = el.value;
        });
        return Object.values(aliases);
    }

    // Format a name object {first, middle, last} into "Last, First M." style.
    function formatAliasName(a) {
        var first = (a.first || '').trim();
        var middle = (a.middle || '').trim();
        var last = (a.last || '').trim();
        if (!first && !last) { return ''; }
        var middleInitial = middle.length ? (' ' + middle.charAt(0)) : '';
        if (first && last) { return last + ', ' + first + middleInitial; }
        return (first + ' ' + last).trim();
    }

    // Build the ordered list of search terms to try for an LDAP name-based lookup.
    // Returns an array: name terms first (deduplicated), email as final fallback.
    function buildLdapSearchTerms(cougarnetEl, emailEl) {
        var aliases = readAliasesFromDOM();
        var nameTerms = [];
        var seen = {};

        // If CougarNet ID is populated, use it exclusively (sAMAccountName match).
        if (cougarnetEl && cougarnetEl.value.trim().length) {
            return [cougarnetEl.value.trim()];
        }

        // Check for an alias flagged as LDAP source — if found, use only that one.
        var ldapAlias = null;
        for (var i = 0; i < aliases.length; i++) {
            if ((aliases[i].source || '').trim().toUpperCase() === 'LDAP') {
                ldapAlias = aliases[i];
                break;
            }
        }

        if (ldapAlias) {
            var t = formatAliasName(ldapAlias);
            if (t.length >= 2) { nameTerms.push(t); }
        } else {
            // Use all aliases.
            for (var j = 0; j < aliases.length; j++) {
                var term = formatAliasName(aliases[j]);
                if (term.length >= 2 && !seen[term]) {
                    seen[term] = true;
                    nameTerms.push(term);
                }
            }

            // Also include the canonical name from the form fields.
            var firstEl  = document.querySelector('#general-pane [name="FirstName"]');
            var middleEl = document.querySelector('#general-pane [name="MiddleName"]');
            var lastEl   = document.querySelector('#general-pane [name="LastName"]');
            var canonical = formatAliasName({
                first:  firstEl  ? firstEl.value  : '',
                middle: middleEl ? middleEl.value : '',
                last:   lastEl   ? lastEl.value   : ''
            });
            if (canonical.length >= 2 && !seen[canonical]) {
                seen[canonical] = true;
                nameTerms.push(canonical);
            }
        }

        // Email fallback appended last.
        var email = emailEl ? emailEl.value.trim() : '';
        if (email.length >= 2 && !seen[email]) {
            nameTerms.push(email);
        }

        return nameTerms;
    }

    // Run one LDAP fetch for a single search term; resolves with the payload.
    function fetchLdapTerm(term) {
        var body = new URLSearchParams();
        body.append('searchTerm', term);
        body.append('userID', pageUserID);
        body.append('maxRows', '25');
        return fetch('/admin/users/ldap_lookup.cfm', {
            method: 'POST',
            body: body,
            credentials: 'same-origin'
        }).then(function (r) { return r.json(); });
    }

    // Try each search term in sequence; stop as soon as one returns rows.
    function fetchLdapSequential(terms) {
        if (!terms.length) {
            return Promise.resolve({ success: false, message: 'No search terms available.', data: [] });
        }
        return fetchLdapTerm(terms[0]).then(function (payload) {
            var ok   = payload && payload.success === true;
            var rows = payload ? (payload.data || []) : [];
            if (ok && rows.length > 0) {
                return payload;
            }
            // No results — try remaining terms.
            var remaining = terms.slice(1);
            if (!remaining.length) {
                return payload; // Return the last (empty) payload as the final answer.
            }
            return fetchLdapSequential(remaining);
        });
    }

    document.addEventListener('click', function (event) {
        var lookupBtn = event.target.closest('.js-cougarnet-lookup');
        if (lookupBtn) {
            var cougarnetEl = document.getElementById('extid-cougarnet-input');
            var emailEl = document.querySelector('#admin-pane [name="EmailPrimary"]') || document.querySelector('#general-pane [name="EmailPrimary"]');
            var searchTerms = buildLdapSearchTerms(cougarnetEl, emailEl);

            if (!searchTerms.length || (searchTerms.length === 1 && searchTerms[0].length < 2)) {
                setExtidsLdapStatus('Enter at least 2 characters in CougarNet ID, email, or name before lookup.', true);
                return;
            }

            lookupBtn.disabled = true;
            setExtidsLdapStatus('Searching LDAP...', false);

            fetchLdapSequential(searchTerms)
            .then(function (payload) {
                var ok = payload && payload.success === true;
                var message = payload ? (payload.message || '') : '';
                var rows = payload ? (payload.data || []) : [];

                if (!ok) {
                    extidsLdapRows = [];
                    renderExtidsLdapRows(extidsLdapRows);
                    setExtidsLdapStatus(message || 'Lookup failed.', true);
                    if (extidsLdapModal) { extidsLdapModal.show(); }
                    return;
                }

                extidsLdapRows = rows.map(normalizeLdapRow);
                renderExtidsLdapRows(extidsLdapRows);
                setExtidsLdapStatus(extidsLdapRows.length + ' match(es) found.', false);
                if (extidsLdapModal) { extidsLdapModal.show(); }
            })
            .catch(function (err) {
                setExtidsLdapStatus('Network error: ' + err.message, true);
            })
            .finally(function () {
                lookupBtn.disabled = false;
            });
            return;
        }

        var selectBtn = event.target.closest('.js-extids-ldap-select');
        if (selectBtn) {
            var idx = parseInt(selectBtn.getAttribute('data-idx'), 10);
            var row = extidsLdapRows[idx] || null;
            var cougarnetInput = document.getElementById('extid-cougarnet-input');
            var peoplesoftInput = document.getElementById('extid-peoplesoft-input');
            if (row) {
                if (cougarnetInput) {
                    cougarnetInput.value = row.samAccountName || '';
                }
                if (peoplesoftInput) {
                    peoplesoftInput.value = row.employeeID || '';
                }
                markDirty('extids');
                setExtidsLdapStatus('Selected ' + (row.samAccountName || '') + '.', false);

                if (row.mail) {
                    var emailBody = new URLSearchParams();
                    emailBody.append('userID', pageUserID);
                    emailBody.append('section', 'addLdapEmailIfMissing');
                    emailBody.append('email', row.mail);
                    fetch('/admin/users/saveSection.cfm', {
                        method: 'POST',
                        body: emailBody,
                        credentials: 'same-origin'
                    })
                    .then(function (r) { return r.json(); })
                    .then(function (payload) {
                        if (payload && payload.success && payload.data && payload.data.inserted) {
                            setExtidsLdapStatus('Selected ' + (row.samAccountName || '') + ' and added email ' + row.mail + '.', false);
                        }
                    })
                    .catch(function () {
                        // Ignore background email sync failures to keep lookup UX smooth.
                    });
                }

                if (row.displayName) {
                    var aliasBody = new URLSearchParams();
                    aliasBody.append('userID', pageUserID);
                    aliasBody.append('section', 'addLdapAliasIfMissing');
                    aliasBody.append('displayName', row.displayName);
                    fetch('/admin/users/saveSection.cfm', {
                        method: 'POST',
                        body: aliasBody,
                        credentials: 'same-origin'
                    })
                    .catch(function () {
                        // Ignore background alias sync failures to keep lookup UX smooth.
                    });
                }
            }
            if (extidsLdapModal) {
                extidsLdapModal.hide();
            }
        }
    });

    var saveExtidsBtn = document.getElementById('save-extids-btn');
    if (saveExtidsBtn) {
        saveExtidsBtn.addEventListener('click', function () {
            var pane = document.getElementById('extids-pane');
            var body = new URLSearchParams();
            body.append('userID', pageUserID);
            body.append('section', 'extids');
            pane.querySelectorAll('input[name^="extID_"]').forEach(function (inp) {
                body.append(inp.name, inp.value);
            });
            saveSectionAjax('extids', body, document.getElementById('save-extids-status'));
        });
    }

    var savePublicationsBtn = document.getElementById('save-publications-btn');
    var publicationsPane = document.getElementById('publications-pane');

    function buildPublicationsSaveBody(overrideShowcasedIDs) {
        var pane = document.getElementById('publications-pane');
        var body = new URLSearchParams();
        var showcasedIDs = Array.isArray(overrideShowcasedIDs) ? overrideShowcasedIDs.slice() : [];
        var orderMap = {};
        var showcasedList = pane ? pane.querySelectorAll('.showcased-publication-item') : [];

        if (!pane) {
            return null;
        }

        if (!Array.isArray(overrideShowcasedIDs)) {
            showcasedList.forEach(function (item) {
                showcasedIDs.push(item.getAttribute('data-publication-id'));
            });
        }

        showcasedIDs.forEach(function (publicationID, index) {
            orderMap[String(publicationID)] = String(index + 1);
        });

        body.append('userID', pageUserID);
        body.append('section', 'publications');
        body.append('orcid_identifier', (pane.querySelector('[name="orcid_identifier"]') || {}).value || '');
        body.append('orcid_url', (pane.querySelector('[name="orcid_url"]') || {}).value || '');
        body.append('orcid_enabled', pane.querySelector('[name="orcid_enabled"]') && pane.querySelector('[name="orcid_enabled"]').checked ? '1' : '0');
        body.append('showcased_publication_ids', showcasedIDs.join(','));
        body.append('publication_display_order_json', JSON.stringify(orderMap));

        return body;
    }

    function persistPublicationShowcase(showcasedIDs) {
        var body = buildPublicationsSaveBody(showcasedIDs);
        var statusEl = document.getElementById('save-publications-status');

        if (!body) {
            return;
        }

        saveSectionAjax('publications', body, statusEl, function () {
            refreshTabData('publications-tab');
        });
    }

    if (savePublicationsBtn) {
        savePublicationsBtn.addEventListener('click', function () {
            var pane = document.getElementById('publications-pane');
            var body = buildPublicationsSaveBody();

            if (!pane || !body) {
                return;
            }

            saveSectionAjax('publications', body, document.getElementById('save-publications-status'));
        });
    }

    if (publicationsPane) {
        publicationsPane.addEventListener('click', function (event) {
            var moveBtn = event.target.closest('.publication-showcase-move-btn');
            var showcasedPanel = publicationsPane.querySelector('#showcasedPublicationsList');
            var maxSource = publicationsPane.querySelector('#publicationsPanels');
            var maxCount = maxSource ? parseInt(maxSource.getAttribute('data-max-showcased') || '10', 10) || 10 : 10;
            var showcasedIDs = [];
            var publicationID = '';

            if (!moveBtn || !showcasedPanel) {
                return;
            }

            publicationID = moveBtn.getAttribute('data-publication-id') || '';
            showcasedPanel.querySelectorAll('.showcased-publication-item').forEach(function (item) {
                showcasedIDs.push(item.getAttribute('data-publication-id'));
            });

            if (moveBtn.getAttribute('data-direction') === 'add') {
                if (showcasedIDs.indexOf(publicationID) === -1) {
                    if (maxCount > 0 && showcasedIDs.length >= maxCount) {
                        showSaveToast('You can showcase at most ' + maxCount + ' publications.', true);
                        return;
                    }
                    showcasedIDs.push(publicationID);
                }
            } else {
                showcasedIDs = showcasedIDs.filter(function (id) {
                    return id !== publicationID;
                });
            }

            persistPublicationShowcase(showcasedIDs);
        });
    }

    var fetchOrcidBtn = document.getElementById('fetch-orcid-btn');
    var fetchOrcidStatus = document.getElementById('fetch-orcid-status');
    var orcidIdentifierInput = document.getElementById('orcidIdentifier');
    var limitRecentPublicationYears = document.getElementById('limitRecentPublicationYears');

    function syncOrcidFetchButtonState() {
        if (!fetchOrcidBtn || !orcidIdentifierInput) {
            return;
        }
        fetchOrcidBtn.disabled = !(orcidIdentifierInput.value || '').trim();
    }

    if (orcidIdentifierInput) {
        syncOrcidFetchButtonState();
        orcidIdentifierInput.addEventListener('input', syncOrcidFetchButtonState);
    }

    if (fetchOrcidBtn) {
        fetchOrcidBtn.addEventListener('click', function () {
            var orcidValue = (orcidIdentifierInput ? orcidIdentifierInput.value : '').trim();

            fetchOrcidBtn.disabled = true;

            function doFetch() {
                var body = new URLSearchParams();
                body.append('userID', pageUserID);
                body.append('serviceCode', 'orcid');
                body.append('limitRecentYears', limitRecentPublicationYears && limitRecentPublicationYears.checked ? '1' : '0');

                if (fetchOrcidStatus) {
                    fetchOrcidStatus.textContent = 'Fetching ORCID works...';
                }

                fetch('/admin/users/fetchPublications.cfm', {
                    method: 'POST',
                    body: body,
                    credentials: 'same-origin'
                })
                .then(function (r) { return r.json(); })
                .then(function (data) {
                    if (data.success) {
                        if (fetchOrcidStatus) {
                            fetchOrcidStatus.textContent = 'Fetched ' + (data.data && data.data.recordsFetched ? data.data.recordsFetched : 0) + ' ORCID work(s). Refreshing...';
                        }
                        showSaveToast(data.message || 'ORCID publications fetched.');
                        window.location.reload();
                        return;
                    }

                    if (fetchOrcidStatus) {
                        fetchOrcidStatus.textContent = data.message || 'ORCID fetch failed.';
                    }
                    showSaveToast(data.message || 'ORCID fetch failed.', true);
                    syncOrcidFetchButtonState();
                })
                .catch(function (err) {
                    if (fetchOrcidStatus) {
                        fetchOrcidStatus.textContent = 'Network error during ORCID fetch.';
                    }
                    showSaveToast('Network error: ' + (err && err.message ? err.message : 'Unknown'), true);
                    syncOrcidFetchButtonState();
                });
            }

            // If the ORCID field has a value, save it first so the fetch always
            // uses the ID currently visible in the field, not a stale saved value.
            if (orcidValue) {
                var saveBody = buildPublicationsSaveBody();
                if (fetchOrcidStatus) {
                    fetchOrcidStatus.textContent = 'Saving ORCID...';
                }

                fetch('/admin/users/saveSection.cfm', { method: 'POST', body: saveBody })
                .then(function (r) { return r.json(); })
                .then(function (data) {
                    if (!data.success) {
                        if (fetchOrcidStatus) {
                            fetchOrcidStatus.textContent = data.message || 'Could not save ORCID before fetching.';
                        }
                        showSaveToast(data.message || 'Could not save ORCID before fetching.', true);
                        syncOrcidFetchButtonState();
                        return;
                    }
                    clearDirty('publications');
                    doFetch();
                })
                .catch(function (err) {
                    if (fetchOrcidStatus) {
                        fetchOrcidStatus.textContent = 'Network error saving ORCID.';
                    }
                    showSaveToast('Network error: ' + (err && err.message ? err.message : 'Unknown'), true);
                    syncOrcidFetchButtonState();
                });
            } else {
                doFetch();
            }
        });
    }

    /* ── Dropbox Folder Verify / Create (SuperAdmin) ── */
    var dropboxConfirmModalEl = document.getElementById('dropboxConfirmModal');
    var dropboxConfirmModal   = dropboxConfirmModalEl ? new bootstrap.Modal(dropboxConfirmModalEl) : null;
    var _dropboxConfirmCb     = null;

    function showDropboxConfirm(title, bodyHtml, onConfirm) {
        var titleEl = document.getElementById('dropboxConfirmModalLabel');
        var bodyEl  = document.getElementById('dropboxConfirmModalBody');
        if (titleEl) titleEl.textContent = title;
        if (bodyEl)  bodyEl.innerHTML    = bodyHtml;
        _dropboxConfirmCb = onConfirm;
        if (dropboxConfirmModal) dropboxConfirmModal.show();
    }

    var dropboxConfirmBtn = document.getElementById('dropboxConfirmModalBtn');
    if (dropboxConfirmBtn) {
        dropboxConfirmBtn.addEventListener('click', function () {
            if (dropboxConfirmModal) dropboxConfirmModal.hide();
            if (_dropboxConfirmCb) { var cb = _dropboxConfirmCb; _dropboxConfirmCb = null; cb(); }
        });
    }

    var verifyDropboxBtn = document.getElementById('verifyDropboxFolderBtn');
    if (verifyDropboxBtn) {
        verifyDropboxBtn.addEventListener('click', function () {
            var btn        = this;
            var statusEl   = document.getElementById('dropboxFolderCheckStatus');
            var resultEl   = document.getElementById('dropboxFolderCheckResult');
            var targetUID  = btn.dataset.userid;

            btn.disabled = true;
            if (statusEl) statusEl.textContent = 'Checking…';
            if (resultEl) { resultEl.innerHTML = ''; resultEl.classList.add('d-none'); }

            var body = new URLSearchParams();
            body.append('userID', targetUID);

            fetch('/admin/users/check_dropbox_folder.cfm', { method: 'POST', body: body })
            .then(function (r) { return r.json(); })
            .then(function (data) {
                btn.disabled = false;
                if (statusEl) statusEl.textContent = '';
                if (!resultEl) return;

                var html = '';
                if (!data.success) {
                    html = '<div class="alert alert-danger py-2 mb-0"><i class="bi bi-exclamation-triangle me-1"></i>' + (data.message || 'An error occurred.') + '</div>';
                } else if (!data.data || !data.data.primaryFolder) {
                    html = '<div class="alert alert-secondary py-2 mb-0"><i class="bi bi-info-circle me-1"></i>' + (data.message || 'Could not determine folder name.') + '</div>';
                } else if (data.data.exists) {
                    var publishLabel = data.data.publishExists ? '<span class="text-success small ms-2"><i class="bi bi-check-circle me-1"></i>publish present</span>' : '<span class="text-warning small ms-2"><i class="bi bi-exclamation-circle me-1"></i>publish missing</span>';
                    html = '<div class="alert alert-success d-flex align-items-center gap-3 py-2 mb-0">'
                         + '<i class="bi bi-folder-check fs-5 flex-shrink-0"></i>'
                         + '<div><strong>Folder Available</strong> <code class="ms-1">' + (data.data.folderPath || '') + '</code>' + publishLabel + '</div>'
                         + '<a href="/admin/user-media/sources.cfm?userid=' + targetUID + '" class="btn btn-sm btn-ui-outline ms-auto" target="_blank"><i class="bi bi-card-image me-1"></i>User-Media</a>'
                         + '</div>';
                } else if (data.data.legacyExists) {
                    html = '<div class="alert alert-warning d-flex align-items-center gap-3 py-2 mb-0">'
                         + '<i class="bi bi-folder-symlink fs-5 flex-shrink-0"></i>'
                         + '<div>'
                         + '<strong>Legacy Folder Found</strong>'
                         + ' <code class="ms-1">' + (data.data.legacyFolderPath || '') + '</code>'
                         + '<div class="text-muted small mt-1">Rename to <code>' + (data.data.folderPath || '') + '</code></div>'
                         + '</div>'
                         + '<button type="button" id="renameDropboxFolderBtn" class="btn btn-sm btn-ui-outline ms-auto"'
                         + ' data-userid="' + targetUID + '" data-frompath="' + (data.data.legacyFolderPath || '') + '" data-topath="' + (data.data.folderPath || '') + '">'
                         + '<i class="bi bi-pencil-square me-1"></i>Rename to Convention</button>'
                         + '</div>';
                } else {
                    html = '<div class="alert alert-warning d-flex align-items-center gap-3 py-2 mb-0">'
                         + '<i class="bi bi-folder-x fs-5 flex-shrink-0"></i>'
                         + '<div><strong>Folder Missing</strong> <code class="ms-1">' + (data.data.folderPath || '') + '</code></div>'
                         + '<button type="button" id="createDropboxFolderBtn" class="btn btn-sm btn-ui-add ms-auto"'
                         + ' data-userid="' + targetUID + '" data-folderpath="' + (data.data.folderPath || '') + '">'
                         + '<i class="bi bi-folder-plus me-1"></i>Create Folder</button>'
                         + '</div>';
                }
                resultEl.innerHTML = html;
                resultEl.classList.remove('d-none');
            })
            .catch(function (err) {
                btn.disabled = false;
                if (statusEl) statusEl.textContent = '';
                if (resultEl) {
                    resultEl.innerHTML = '<div class="alert alert-danger py-2 mb-0"><i class="bi bi-exclamation-triangle me-1"></i>Network error: ' + (err && err.message ? err.message : 'Unknown') + '</div>';
                    resultEl.classList.remove('d-none');
                }
            });
        });

        // Delegated click for the Create Folder button (injected dynamically)
        var dropboxResultEl = document.getElementById('dropboxFolderCheckResult');
        if (dropboxResultEl) {
            dropboxResultEl.addEventListener('click', function (e) {
                // Rename legacy folder to primary convention
                var renameBtn = e.target.closest('#renameDropboxFolderBtn');
                if (renameBtn) {
                    var targetUID = renameBtn.dataset.userid;
                    var fromPath  = renameBtn.dataset.frompath || '';
                    var toPath    = renameBtn.dataset.topath   || '';

                    showDropboxConfirm(
                        'Rename Folder',
                        'Rename <code>' + fromPath + '</code><br>to <code>' + toPath + '</code> in Dropbox?',
                        function () {
                    renameBtn.disabled = true;
                    renameBtn.innerHTML = '<i class="bi bi-hourglass-split me-1"></i>Renaming…';

                    var body = new URLSearchParams();
                    body.append('userID', targetUID);

                    fetch('/admin/users/rename_dropbox_folder.cfm', { method: 'POST', body: body })
                    .then(function (r) { return r.json(); })
                    .then(function (data) {
                        if (!data.success) {
                            renameBtn.disabled = false;
                            renameBtn.innerHTML = '<i class="bi bi-pencil-square me-1"></i>Rename to Convention';
                            var errDiv = document.createElement('div');
                            errDiv.className = 'alert alert-danger py-2 mt-2 mb-0';
                            errDiv.innerHTML = '<i class="bi bi-exclamation-triangle me-1"></i>' + (data.message || 'Rename failed.');
                            dropboxResultEl.appendChild(errDiv);
                            return;
                        }
                        var publishLabel = data.data.publishCreated ? '<span class="text-success small ms-2"><i class="bi bi-check-circle me-1"></i>publish present</span>' : '<span class="text-muted small ms-2">publish already existed</span>';
                        dropboxResultEl.innerHTML = '<div class="alert alert-success d-flex align-items-center gap-3 py-2 mb-0">'
                            + '<i class="bi bi-folder-check fs-5 flex-shrink-0"></i>'
                            + '<div><strong>Folder Available</strong> <code class="ms-1">' + (data.data.toPath || '') + '</code>' + publishLabel + '</div>'
                            + '<a href="/admin/user-media/sources.cfm?userid=' + targetUID + '" class="btn btn-sm btn-ui-outline ms-auto" target="_blank"><i class="bi bi-card-image me-1"></i>User-Media</a>'
                            + '</div>';
                        showSaveToast('Dropbox folder renamed successfully.');
                    })
                    .catch(function (err) {
                        renameBtn.disabled = false;
                        renameBtn.innerHTML = '<i class="bi bi-pencil-square me-1"></i>Rename to Convention';
                        var errDiv = document.createElement('div');
                        errDiv.className = 'alert alert-danger py-2 mt-2 mb-0';
                        errDiv.innerHTML = '<i class="bi bi-exclamation-triangle me-1"></i>Network error: ' + (err && err.message ? err.message : 'Unknown');
                        dropboxResultEl.appendChild(errDiv);
                    });
                        } // end showDropboxConfirm callback
                    );
                    return;
                }

                var createBtn = e.target.closest('#createDropboxFolderBtn');
                if (!createBtn) return;

                var targetUID  = createBtn.dataset.userid;
                var folderPath = createBtn.dataset.folderpath || '';

                showDropboxConfirm(
                    'Create Folder',
                    'Create <code>' + folderPath + '</code> and a <code>publish</code> subfolder in Dropbox?',
                    function () {
                createBtn.disabled = true;
                createBtn.innerHTML = '<i class="bi bi-hourglass-split me-1"></i>Creating…';

                var body = new URLSearchParams();
                body.append('userID', targetUID);

                fetch('/admin/users/create_dropbox_folder.cfm', { method: 'POST', body: body })
                .then(function (r) { return r.json(); })
                .then(function (data) {
                    if (!data.success) {
                        createBtn.disabled = false;
                        createBtn.innerHTML = '<i class="bi bi-folder-plus me-1"></i>Create Folder';
                        var errDiv = document.createElement('div');
                        errDiv.className = 'alert alert-danger py-2 mt-2 mb-0';
                        errDiv.innerHTML = '<i class="bi bi-exclamation-triangle me-1"></i>' + (data.message || 'Create failed.');
                        dropboxResultEl.appendChild(errDiv);
                        return;
                    }
                    // Replace result with "Folder Available" state
                    var publishLabel = data.data.publishCreated ? '<span class="text-success small ms-2"><i class="bi bi-check-circle me-1"></i>publish present</span>' : '<span class="text-warning small ms-2"><i class="bi bi-exclamation-circle me-1"></i>publish missing</span>';
                    dropboxResultEl.innerHTML = '<div class="alert alert-success d-flex align-items-center gap-3 py-2 mb-0">'
                        + '<i class="bi bi-folder-check fs-5 flex-shrink-0"></i>'
                        + '<div><strong>Folder Available</strong> <code class="ms-1">' + (data.data.folderPath || '') + '</code>' + publishLabel + '</div>'
                        + '<a href="/admin/user-media/sources.cfm?userid=' + targetUID + '" class="btn btn-sm btn-ui-outline ms-auto" target="_blank"><i class="bi bi-card-image me-1"></i>User-Media</a>'
                        + '</div>';
                    showSaveToast('Dropbox folder created successfully.');
                })
                .catch(function (err) {
                    createBtn.disabled = false;
                    createBtn.innerHTML = '<i class="bi bi-folder-plus me-1"></i>Create Folder';
                    var errDiv = document.createElement('div');
                    errDiv.className = 'alert alert-danger py-2 mt-2 mb-0';
                    errDiv.innerHTML = '<i class="bi bi-exclamation-triangle me-1"></i>Network error: ' + (err && err.message ? err.message : 'Unknown');
                    dropboxResultEl.appendChild(errDiv);
                });
                    } // end showDropboxConfirm callback
                );
            });
        }
    }

    /* ── UH Admin tab (SuperAdmin) ── */
    var saveUhBtn = document.getElementById('save-uh-btn');
    if (saveUhBtn) {
        saveUhBtn.addEventListener('click', function () {
            var pane = document.getElementById('admin-pane');
            var body = new URLSearchParams();
            body.append('userID', pageUserID);
            body.append('section', 'uh');
            ['EmailPrimary','UH_API_ID','Room','Building','Campus','Division','DivisionName','Department','DepartmentName','Office_Mailing_Address','Mailcode','Notes'].forEach(function (f) {
                var el = pane.querySelector('[name="' + f + '"]');
                body.append(f, el ? el.value : '');
            });
            saveSectionAjax('uh', body, document.getElementById('save-uh-status'));
        });
    }

    /* ── Copy Office Mailing Address → Addresses tab ── */
    var copyAddrBtn = document.getElementById('copyToAddressesBtn');
    if (copyAddrBtn) {
        copyAddrBtn.addEventListener('click', function () {
            var raw = (document.getElementById('officeMailingAddress').value || '').trim();
            if (!raw) { showValidationError('Office Mailing Address is empty.'); return; }

            /* Parse: "4349 Martin Luther King Blvd Health 1 RM 230 Houston, TX 77204-2020" */
            var parsed = { type: 'Office', addr1: '', addr2: '', city: '', state: '', zip: '',
                           building: '', room: '', mailcode: '', primary: '0' };

            var work = raw;

            /* Extract Room: RM/Room followed by digits */
            var rmMatch = work.match(/\b(?:RM|Room)\s+(\S+)/i);
            if (rmMatch) {
                parsed.room = rmMatch[1];
                work = work.replace(rmMatch[0], '').trim();
            }

            /* Known addresses and buildings for UHCO campus — match these FIRST
               so that punctuation in building names (e.g. "J. Davis Armistead")
               doesn't confuse the city/state/zip regex. */
            var knownAddresses = [
                { street: '4401 Martin Luther King Blvd', building: 'J. Davis Armistead' },
                { street: '4349 Martin Luther King Blvd', building: 'Health 1' }
            ];
            var matched = false;
            for (var ki = 0; ki < knownAddresses.length; ki++) {
                var ka = knownAddresses[ki];
                if (work.indexOf(ka.street) === 0) {
                    parsed.addr1 = ka.street;
                    var remainder = work.substring(ka.street.length).trim();
                    /* Strip known building name from the front of remainder */
                    if (remainder.indexOf(ka.building) === 0) {
                        parsed.building = ka.building;
                        remainder = remainder.substring(ka.building.length).trim();
                    }
                    /* Whatever is left should be "Houston, TX 77204-2020" */
                    var cszMatch = remainder.match(/,?\s*([A-Za-z\s]+),\s*([A-Z]{2})\s+(\d{5}(?:-\d{4})?)\s*$/);
                    if (cszMatch) {
                        parsed.city  = cszMatch[1].trim();
                        parsed.state = cszMatch[2];
                        parsed.zip   = cszMatch[3];
                    } else if (!parsed.building && remainder.length) {
                        /* Couldn't parse city/state — put leftover in building */
                        parsed.building = remainder;
                    }
                    matched = true;
                    break;
                }
            }

            if (!matched) {
                /* Extract City, State ZIP from the end: "Houston, TX 77204-2020" */
                var cszMatch = work.match(/,?\s*([A-Za-z\s]+),\s*([A-Z]{2})\s+(\d{5}(?:-\d{4})?)\s*$/);
                if (cszMatch) {
                    parsed.city  = cszMatch[1].trim();
                    parsed.state = cszMatch[2];
                    parsed.zip   = cszMatch[3];
                    work = work.substring(0, work.length - cszMatch[0].length).trim();
                }
                /* Fallback: split at street suffix */
                var streetEnd = work.search(/\b(Blvd|Boulevard|St|Street|Ave|Avenue|Dr|Drive|Rd|Road|Hwy|Highway|Pkwy|Parkway|Way|Lane|Ln|Circle|Cir)\b\.?\s*/i);
                if (streetEnd >= 0) {
                    var suffixMatch = work.substring(streetEnd).match(/^(\S+\.?)\s*(.*)/);
                    if (suffixMatch) {
                        parsed.addr1 = work.substring(0, streetEnd).trim() + ' ' + suffixMatch[1];
                        parsed.building = (suffixMatch[2] || '').trim();
                    }
                } else {
                    parsed.addr1 = work;
                }
            }

            /* Pull Mailcode from the UH pane if present */
            var mcEl = document.querySelector('[name="Mailcode"]');
            if (mcEl && mcEl.value.trim()) { parsed.mailcode = mcEl.value.trim(); }

            /* Pre-fill the address modal with parsed values for user review */
            document.getElementById('addrEditIdx').value = '-1';
            document.getElementById('addrType').value = parsed.type;
            document.getElementById('addrAddr1').value = parsed.addr1;
            document.getElementById('addrAddr2').value = parsed.addr2;
            document.getElementById('addrCity').value = parsed.city;
            document.getElementById('addrState').value = parsed.state;
            document.getElementById('addrZip').value = parsed.zip;
            document.getElementById('addrBuilding').value = parsed.building;
            document.getElementById('addrRoom').value = parsed.room;
            document.getElementById('addrMailcode').value = parsed.mailcode;
            document.getElementById('addrPrimary').checked = false;
            document.getElementById('addressModalLabel').textContent = 'Review Parsed Address';

            /* Swap buttons: hide the JS-only Save, show the Save to Database button */
            document.getElementById('saveAddressBtn').classList.add('d-none');
            document.getElementById('saveAddressToDbBtn').classList.remove('d-none');

            var addrModal = bootstrap.Modal.getOrCreateInstance(document.getElementById('addressModal'));
            addrModal.show();
        });
    }

    /* Save to Database button — direct AJAX insert for copied addresses */
    var saveToDbBtn = document.getElementById('saveAddressToDbBtn');
    if (saveToDbBtn) {
        saveToDbBtn.addEventListener('click', function () {
            var body = new URLSearchParams();
            body.append('userID', pageUserID);
            body.append('section', 'addAddress');
            body.append('type', document.getElementById('addrType').value);
            body.append('addr1', document.getElementById('addrAddr1').value.trim());
            body.append('addr2', document.getElementById('addrAddr2').value.trim());
            body.append('city', document.getElementById('addrCity').value.trim());
            body.append('state', document.getElementById('addrState').value.trim());
            body.append('zip', document.getElementById('addrZip').value.trim());
            body.append('building', document.getElementById('addrBuilding').value.trim());
            body.append('room', document.getElementById('addrRoom').value.trim());
            body.append('mailcode', document.getElementById('addrMailcode').value.trim());
            body.append('primary', document.getElementById('addrPrimary').checked ? '1' : '0');

            saveToDbBtn.disabled = true;
            saveToDbBtn.textContent = 'Saving...';

            fetch('/admin/users/saveSection.cfm', { method: 'POST', body: body })
                .then(function (r) { return r.json(); })
                .then(function (data) {
                    if (data.success) {
                        /* Add the new address card to the Contact tab via exposed helpers */
                        var addrContainer = document.getElementById('addressesContainer');
                        if (addrContainer && addrContainer._addrGetAllData && addrContainer._addrRebuild) {
                            var items = addrContainer._addrGetAllData();
                            items.push({
                                type: document.getElementById('addrType').value,
                                addr1: document.getElementById('addrAddr1').value.trim(),
                                addr2: document.getElementById('addrAddr2').value.trim(),
                                city: document.getElementById('addrCity').value.trim(),
                                state: document.getElementById('addrState').value.trim(),
                                zip: document.getElementById('addrZip').value.trim(),
                                building: document.getElementById('addrBuilding').value.trim(),
                                room: document.getElementById('addrRoom').value.trim(),
                                mailcode: document.getElementById('addrMailcode').value.trim(),
                                primary: document.getElementById('addrPrimary').checked ? '1' : '0'
                            });
                            addrContainer._addrRebuild(items);
                        }
                        bootstrap.Modal.getInstance(document.getElementById('addressModal')).hide();
                    } else {
                        showSaveToast('Error: ' + (data.message || 'Save failed.'), true);
                    }
                })
                .catch(function (err) { showSaveToast('Network error: ' + err.message, true); })
                .finally(function () {
                    saveToDbBtn.disabled = false;
                    saveToDbBtn.textContent = 'Save to Database';
                });
        });
    }

    /* Reset address modal buttons when closed */
    var addrModalEl = document.getElementById('addressModal');
    if (addrModalEl) {
        addrModalEl.addEventListener('hidden.bs.modal', function () {
            document.getElementById('saveAddressBtn').classList.remove('d-none');
            document.getElementById('saveAddressToDbBtn').classList.add('d-none');
        });
    }

    /* ── Biographical Info tab (DOB, Gender) ── */
    var saveBioinfoBtn = document.getElementById('save-bioinfo-btn');
    if (saveBioinfoBtn) {
        saveBioinfoBtn.addEventListener('click', function () {
            var pane = document.getElementById('bio-info-pane');
            var body = new URLSearchParams();
            body.append('userID', pageUserID);
            body.append('section', 'bioinfo');
            var dobEl = pane.querySelector('[name="DOB"]');
            var genEl = pane.querySelector('[name="Gender"]');
            body.append('DOB', dobEl ? dobEl.value : '');
            body.append('Gender', genEl ? genEl.value : '');

            ['CurrentGradYear','OriginalGradYear','sp_first_externship','sp_second_externship','sp_commencement_age','sp_dissertation_thesis'].forEach(function (f) {
                var el = pane.querySelector('[name="' + f + '"]');
                body.append(f, el ? el.value : '');
            });

            var editorEl = pane ? pane.querySelector('.users-edit-bio-editor') : null;
            var editorBody = editorEl ? editorEl.querySelector('.ql-editor') : null;
            var html = editorBody ? editorBody.innerHTML : '';
            if (html === '<p><br></p>') html = '';
            body.append('bioContent', html);

            saveSectionAjax('bioinfo', body, document.getElementById('save-bioinfo-status'));
        });
    }

    /* ── UHCO degree field toggles (inline degree rows in all tab panels) ── */
    document.addEventListener('change', function (e) {
        var row = e.target.closest('.degree-row');
        if (!row) return;

        // UHCO checkbox toggles the whole uhco-fields block
        if (e.target.classList.contains('deg-isuhco')) {
            var uhcoBlock = row.querySelector('.uhco-fields');
            if (uhcoBlock) {
                uhcoBlock.classList.toggle('d-none', !e.target.checked);
                row.querySelectorAll('.deg-isenrolled, .deg-haschange, .deg-expgrad, .deg-origexpgrad, .deg-program')
                   .forEach(function(el){ el.disabled = !e.target.checked; });
            }
        }

        // Enrolled checkbox toggles ExpectedGradYear and HasYearChange
        if (e.target.classList.contains('deg-isenrolled')) {
            var enrolled = e.target.checked;
            var expgradEl = row.querySelector('.deg-expgrad');
            var hasChangeEl = row.querySelector('.deg-haschange');
            if (expgradEl) expgradEl.disabled = !enrolled;
            if (hasChangeEl) {
                hasChangeEl.disabled = !enrolled;
                if (!enrolled) { hasChangeEl.checked = false; }
            }
            // Also propagate hasChange state
            var origEl = row.querySelector('.deg-origexpgrad');
            if (origEl) origEl.disabled = !enrolled || !(hasChangeEl && hasChangeEl.checked);
        }

        // HasYearChange checkbox toggles OriginalExpectedGradYear
        if (e.target.classList.contains('deg-haschange')) {
            var origExpEl = row.querySelector('.deg-origexpgrad');
            if (origExpEl) origExpEl.disabled = !e.target.checked;
        }
    });

});