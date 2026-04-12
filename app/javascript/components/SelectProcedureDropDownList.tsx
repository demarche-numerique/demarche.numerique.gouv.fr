import type { ComponentProps } from 'react';

import { SingleComboBox } from './ComboBox';

type Props = ComponentProps<typeof SingleComboBox>;

export default function SelectProcedureDropDownList(props: Props) {
  return <SingleComboBox {...props} />;
}
