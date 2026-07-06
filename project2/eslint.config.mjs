import fioriTools from '@sap-ux/eslint-plugin-fiori-tools';

export default [
    {
        ignores: [
            'webapp/thirdparty/**'
        ]
    },
    ...fioriTools.configs.recommended
];
