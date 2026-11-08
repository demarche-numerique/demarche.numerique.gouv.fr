// Administrate injects its own copy of jQuery

$(document).on('change', '#features input[type=checkbox]', ({ target }) => {
  target = $(target);
  const url = target.data('url');
  const key = target.data('key');
  const value = target.prop('checked');

  $.ajax(url, {
    method: 'put',
    contentType: 'application/json',
    dataType: 'json',
    data: JSON.stringify({
      features: { [key]: value }
    })
  });
});
