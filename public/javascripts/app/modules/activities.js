var Activities = {
  initialize: function() {
  },
  create_on_index: function(data) {
    Utils.log("[create] activity");

    $.get('/activities/'+data.object_id, {notif: 1}, function(data) {
      $("ul.notifications-list li.notification-title").after("<li>"+data+"</li>");

      var counter = $("ul.notifications-list li:first a#notification-counter");
      counter.text(parseInt(counter.text())+1);
    });
  }
};