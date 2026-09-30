jQuery(function() {
	// Close announcer on "x" click
	jQuery('.simple_announcer .dismiss').click(function() {
		jQuery.cookie('announcer_dismiss', true, { expires: 1 });
		jQuery('.simple_announcer').slideUp(200);
	})
});