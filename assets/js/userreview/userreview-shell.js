(function () {
    function escapeHtml(value) {
        return String(value)
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;')
            .replace(/'/g, '&#39;');
    }

    function syncIndexes(containerId, prefix) {
        var rows = document.querySelectorAll('#' + containerId + ' [data-row]');
        rows.forEach(function (row, index) {
            row.querySelectorAll('[data-name]').forEach(function (input) {
                input.name = prefix + '_' + input.dataset.name + '_' + index;
            });
            var radio = row.querySelector('input[type="radio"]');
            if (radio) { radio.value = index; }
        });
        var countField = document.getElementById(prefix + 'Count');
        if (countField) { countField.value = rows.length; }
    }

    // Delegated remove-row handler (replaces onclick="removeRow(...)")
    document.addEventListener('click', function (e) {
        var btn = e.target.closest('[data-remove-row]');
        if (btn) {
            btn.closest('[data-row]').remove();
            syncIndexes(btn.dataset.removeRow, btn.dataset.rowPrefix);
            return;
        }

        // data-add-row — replaces onclick="addAliasRow()" etc.
        var addBtn = e.target.closest('[data-add-row]');
        if (addBtn) {
            switch (addBtn.dataset.addRow) {
                case 'alias':   window.addAliasRow();   break;
                case 'email':   window.addEmailRow();   break;
                case 'phone':   window.addPhoneRow();   break;
                case 'address': window.addAddressRow(); break;
            }
        }
    });

    function removeBtn(containerId, prefix) {
        return '<button type="button" class="btn btn-outline-danger btn-sm"' +
               ' data-remove-row="' + containerId + '" data-row-prefix="' + prefix + '">Remove</button>';
    }

    window.addAliasRow = function (data) {
        data = data || {};
        var container = document.getElementById('aliasRows');
        var isProtected = Number(data.isProtected || 0) === 1;
        var row = document.createElement('div');
        row.className = 'row-card mb-3';
        row.dataset.row = 'alias';
        row.innerHTML =
            '<div class="row g-3 align-items-end">' +
                '<div class="col-md-3">' +
                    '<label class="form-label">First</label>' +
                    '<input class="form-control" data-name="firstName" value="' + escapeHtml(data.firstName || '') + '" ' + (isProtected ? 'readonly' : '') + '>' +
                '</div>' +
                '<div class="col-md-2">' +
                    '<label class="form-label">Middle</label>' +
                    '<input class="form-control" data-name="middleName" value="' + escapeHtml(data.middleName || '') + '" ' + (isProtected ? 'readonly' : '') + '>' +
                '</div>' +
                '<div class="col-md-3">' +
                    '<label class="form-label">Last</label>' +
                    '<input class="form-control" data-name="lastName" value="' + escapeHtml(data.lastName || '') + '" ' + (isProtected ? 'readonly' : '') + '>' +
                '</div>' +
                '<div class="col-md-2">' +
                    '<label class="form-label">Type</label>' +
                    '<input class="form-control" data-name="aliasType" value="' + escapeHtml(data.aliasType || '') + '" ' + (isProtected ? 'readonly' : '') + '>' +
                '</div>' +
                '<div class="col-md-2">' +
                    '<label class="form-label">Source</label>' +
                    '<input class="form-control" data-name="sourceSystem" value="' + escapeHtml(data.sourceSystem || '') + '" readonly>' +
                '</div>' +
                '<div class="col-md-12 d-flex gap-3 align-items-center flex-wrap">' +
                    '<div class="form-check">' +
                        '<input class="form-check-input" type="checkbox" data-name="isActive" ' + (Number(data.isActive || 0) ? 'checked' : '') + ' ' + (isProtected ? 'disabled' : '') + '>' +
                        '<label class="form-check-label">Active</label>' +
                    '</div>' +
                    '<div class="form-check">' +
                        '<input class="form-check-input" type="radio" name="alias_primary" ' + (Number(data.isPrimary || 0) ? 'checked' : '') + ' ' + (isProtected ? 'disabled' : '') + '>' +
                        '<label class="form-check-label">Primary</label>' +
                    '</div>' +
                    ' ' + (isProtected
                        ? '<span class="badge text-bg-secondary">System-managed alias</span>'
                        : removeBtn('aliasRows', 'alias')) +
                '</div>' +
            '</div>';
        container.appendChild(row);
        syncIndexes('aliasRows', 'alias');
    };

    window.addEmailRow = function (data) {
        data = data || {};
        var container = document.getElementById('emailRows');
        var isProtected = Number(data.isProtected || 0) === 1;
        var row = document.createElement('div');
        row.className = 'row-card mb-3';
        row.dataset.row = 'email';
        row.innerHTML =
            '<div class="row g-3 align-items-end">' +
                '<div class="col-md-6">' +
                    '<label class="form-label">Email</label>' +
                    '<input class="form-control" data-name="address" value="' + escapeHtml(data.address || '') + '" ' + (isProtected ? 'readonly' : '') + '>' +
                '</div>' +
                '<div class="col-md-4">' +
                    '<label class="form-label">Type</label>' +
                    '<input class="form-control" data-name="type" value="' + escapeHtml(data.type || '') + '" ' + (isProtected ? 'readonly' : '') + '>' +
                '</div>' +
                '<div class="col-md-2 d-flex gap-2 align-items-center">' +
                    '<div class="form-check mt-4">' +
                        '<input class="form-check-input" type="radio" name="email_primary" ' + (Number(data.isPrimary || 0) ? 'checked' : '') + ' ' + (isProtected ? 'disabled' : '') + '>' +
                        '<label class="form-check-label">Primary</label>' +
                    '</div>' +
                    ' ' + (isProtected
                        ? '<span class="badge text-bg-secondary mt-4">Locked</span>'
                        : removeBtn('emailRows', 'email')) +
                '</div>' +
            '</div>';
        container.appendChild(row);
        syncIndexes('emailRows', 'email');
    };

    window.addPhoneRow = function (data) {
        data = data || {};
        var container = document.getElementById('phoneRows');
        var row = document.createElement('div');
        row.className = 'row-card mb-3';
        row.dataset.row = 'phone';
        row.innerHTML =
            '<div class="row g-3 align-items-end">' +
                '<div class="col-md-6">' +
                    '<label class="form-label">Number</label>' +
                    '<input class="form-control" data-name="number" value="' + escapeHtml(data.number || '') + '">' +
                '</div>' +
                '<div class="col-md-4">' +
                    '<label class="form-label">Type</label>' +
                    '<input class="form-control" data-name="type" value="' + escapeHtml(data.type || '') + '">' +
                '</div>' +
                '<div class="col-md-2 d-flex gap-2 align-items-center">' +
                    '<div class="form-check mt-4">' +
                        '<input class="form-check-input" type="radio" name="phone_primary" ' + (Number(data.isPrimary || 0) ? 'checked' : '') + '>' +
                        '<label class="form-check-label">Primary</label>' +
                    '</div>' +
                    removeBtn('phoneRows', 'phone') +
                '</div>' +
            '</div>';
        container.appendChild(row);
        syncIndexes('phoneRows', 'phone');
    };

    window.addAddressRow = function (data) {
        data = data || {};
        var container = document.getElementById('addressRows');
        var row = document.createElement('div');
        row.className = 'row-card mb-3';
        row.dataset.row = 'address';
        row.innerHTML =
            '<div class="row g-3 align-items-end">' +
                '<div class="col-md-4">' +
                    '<label class="form-label">Type</label>' +
                    '<input class="form-control" data-name="type" value="' + escapeHtml(data.type || '') + '">' +
                '</div>' +
                '<div class="col-md-4">' +
                    '<label class="form-label">Address 1</label>' +
                    '<input class="form-control" data-name="addr1" value="' + escapeHtml(data.addr1 || '') + '">' +
                '</div>' +
                '<div class="col-md-4">' +
                    '<label class="form-label">Address 2</label>' +
                    '<input class="form-control" data-name="addr2" value="' + escapeHtml(data.addr2 || '') + '">' +
                '</div>' +
                '<div class="col-md-3">' +
                    '<label class="form-label">City</label>' +
                    '<input class="form-control" data-name="city" value="' + escapeHtml(data.city || '') + '">' +
                '</div>' +
                '<div class="col-md-2">' +
                    '<label class="form-label">State</label>' +
                    '<input class="form-control" data-name="state" value="' + escapeHtml(data.state || '') + '">' +
                '</div>' +
                '<div class="col-md-2">' +
                    '<label class="form-label">Zip</label>' +
                    '<input class="form-control" data-name="zip" value="' + escapeHtml(data.zip || '') + '">' +
                '</div>' +
                '<div class="col-md-2">' +
                    '<label class="form-label">Building</label>' +
                    '<input class="form-control" data-name="building" value="' + escapeHtml(data.building || '') + '">' +
                '</div>' +
                '<div class="col-md-1">' +
                    '<label class="form-label">Room</label>' +
                    '<input class="form-control" data-name="room" value="' + escapeHtml(data.room || '') + '">' +
                '</div>' +
                '<div class="col-md-2">' +
                    '<label class="form-label">Mailcode</label>' +
                    '<input class="form-control" data-name="mailcode" value="' + escapeHtml(data.mailcode || '') + '">' +
                '</div>' +
                '<div class="col-md-4 d-flex gap-3 align-items-center">' +
                    '<div class="form-check mt-4">' +
                        '<input class="form-check-input" type="radio" name="address_primary" ' + (Number(data.isPrimary || 0) ? 'checked' : '') + '>' +
                        '<label class="form-check-label">Primary</label>' +
                    '</div>' +
                    removeBtn('addressRows', 'address') +
                '</div>' +
            '</div>';
        container.appendChild(row);
        syncIndexes('addressRows', 'address');
    };
})();
