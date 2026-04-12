import ReactOnRails from 'react-on-rails/client';

import SelectProcedureDropDownList from '../components/SelectProcedureDropDownList';

try {
  ReactOnRails.getComponent('SelectProcedureDropDownList');
} catch {
  ReactOnRails.register({ SelectProcedureDropDownList });
}
