import LightningDatatable from 'lightning/datatable';
import picklistCell from './picklistCell.html';
import pickliststatic from './pickliststatic.html'

export default class CustomDatatable extends LightningDatatable {
    static customTypes = {
        picklistColumn: {
            template: pickliststatic,
            editTemplate: picklistCell,
            standardCellLayout: true,
            typeAttributes: ['label', 'placeholder', 'options', 'value', 'context', 'variant','name']
        }
    };
}