(function () {
    var COUNTRY_NAMES = (function () {
        try { return new Intl.DisplayNames(['en'], { type: 'region' }); }
        catch (e) { return null; }
    })();

    function buildCountryOptions(defaultCode) {
        defaultCode = defaultCode || 'US';
        return libphonenumber.getCountries().map(function (code) {
            var name = COUNTRY_NAMES ? COUNTRY_NAMES.of(code) : code;
            return { code: code, label: name + ' (+' + libphonenumber.getCountryCallingCode(code) + ')' };
        }).sort(function (a, b) {
            if (a.code === defaultCode) return -1;
            if (b.code === defaultCode) return 1;
            return a.label.localeCompare(b.label);
        });
    }

    function populateSelect(selectEl, selectedCode) {
        selectedCode = selectedCode || 'US';
        selectEl.innerHTML = '';
        buildCountryOptions(selectedCode).forEach(function (entry) {
            var opt = document.createElement('option');
            opt.value = entry.code;
            opt.textContent = entry.label;
            if (entry.code === selectedCode) opt.selected = true;
            selectEl.appendChild(opt);
        });
    }

    // Live per-country input mask. Re-creates an AsYouType formatter for the
    // selected country and re-feeds the current digit string on every
    // input/country-change event, then relocates the caret by counting how
    // many digits preceded it before the reformat and walking forward the same
    // digit count in the reformatted string (mirrors the caret-preserving
    // technique used by the old fixed NANP mask).
    function wireAsYouType(inputEl, countrySelectEl) {
        function reformat() {
            var digitsBeforeCaret = (inputEl.value.slice(0, inputEl.selectionStart).match(/\d/g) || []).length;
            var formatter = new libphonenumber.AsYouType(countrySelectEl.value);
            var formatted = formatter.input(inputEl.value.replace(/[^\d+]/g, ''));
            inputEl.value = formatted;
            var pos = 0, digitsSeen = 0;
            while (pos < formatted.length && digitsSeen < digitsBeforeCaret) {
                if (/\d/.test(formatted.charAt(pos))) digitsSeen++;
                pos++;
            }
            inputEl.setSelectionRange(pos, pos);
        }

        inputEl.addEventListener('input', reformat);
        countrySelectEl.addEventListener('change', reformat);
    }

    window.PhoneCountryUI = { populateSelect: populateSelect, wireAsYouType: wireAsYouType, buildCountryOptions: buildCountryOptions };
})();
