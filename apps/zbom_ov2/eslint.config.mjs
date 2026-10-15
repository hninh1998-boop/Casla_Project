import fioriTools from '@sap-ux/eslint-plugin-fiori-tools';

export default [
    // abap/ là source backend (abapGit), không thuộc app UI5
    { ignores: ['abap/**'] },
    ...fioriTools.configs.recommended
];
