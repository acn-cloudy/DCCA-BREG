/**********************************************************************
=ON LOAD
**********************************************************************/

jQuery(function() {
	// Asssign shortcuts.
	body = jQuery('body');
//	main_wrapper = jQuery('#main_wrapper');
	
	// Remove no-js class from body
	body.removeClass('no-js');
	
	// Init Nivo Slider.
	if(jQuery('#featured_slider').length) {
		if(slide_counter >= 2) {
			slider_indicators = true;
		}
		else {
			slider_indicators = false;
		}
	}
	else {
		slider_indicators = false;
	}
	
//	if(jQuery('#slides').length) {
//		if(jQuery('#slides').attr('data-transition').length > 0) {
//			var slider_effect = jQuery('#slides').attr('data-transition');
//		}
//		else {
//			var slider_effect = 'random';
//		}
//	}
	
	jQuery('#slides').nivoSlider({
		effect: 'fade',
		directionNav: false,
		controlNav: slider_indicators,
		afterLoad: function() {
			jQuery('#slides').fadeIn(500, function() {
				match_slider();
			});
		}
	});
	
	jQuery('.nivo-control').attr('href', 'javascript:;'); // attach href to nivo button so tab will focus on it
	
	jQuery('.nivo-control').each(function() {
		var button = jQuery(this);
		var slideName = button.text();
		var slideIndex = button.index();
		var postTitle = button.parents('.nivo-controlNav').siblings('.nivoSlider').find('img:eq(' + slideIndex + ')').attr('title');
		var postName = jQuery(postTitle).contents().filter(function() {
			return this.nodeType == 3;
		}).text();
		
		var nameToReplace = slideName + ': ' + postName;
		
		button.text(nameToReplace);
	})
	
	jQuery('body').on('keydown', '.nivo-control', function(event) { // when user tabs onto nivo button
		if(event.keyCode == 13) { // if user hits enter
			jQuery(this).click(); // simulate click on button
			
			/*window.setTimeout(function() { // set focus to slide title
				jQuery('.nivo-caption a').focus();
			}, 200);*/
		}
	});
	
	jQuery('body').on('focus', '.nivo-control, .nivo-caption a', function() { // if use focuses on nivo button
		jQuery('#slides').data('nivoslider').stop(); // stop slider
	});
	
	jQuery('body').on('focusout', '.nivo-control, .nivo-caption a', function() { // if user leaves nivo button
		jQuery('#slides').data('nivoslider').start(); // start slider
	});
	
	 // Font Resizer.
	var default_font_size = body.css('font-size').replace('px', '');
	if(typeof(jQuery.cookie('font-size')) != "undefined" && jQuery.cookie('font-size') !== null) {
	body.css('font-size', jQuery.cookie('font-size') + 'px');
	}
	jQuery('.fontSizePlus').click(function() {
	var current_font_size = body.css('font-size').replace('px', '');
	var size_plus = parseInt(current_font_size) + 2;
	body.css('font-size', size_plus + 'px');
	jQuery.cookie('font-size', size_plus, { path: '/' });
	// Match sidebar_wrapper height with main height.
	if(body.outerWidth() > 767) {
	if(jQuery('#sidebar_wrapper').height() < jQuery('#main').outerHeight()) {
	jQuery('#sidebar_wrapper').height(jQuery('#main').outerHeight());
	}
	else {
	jQuery('#main').height(jQuery('#sidebar_wrapper').outerHeight() - 60);
	}
	}
	});
	jQuery('.fontSizeMinus').click(function() {
	var current_font_size = body.css('font-size').replace('px', '');
	var size_plus = parseInt(current_font_size) - 2;
	body.css('font-size', size_plus + 'px');
	jQuery.cookie('font-size', size_plus, { path: '/' });
	// Match sidebar_wrapper height with main height.
	if(body.outerWidth() > 767) {
	if(jQuery('#sidebar_wrapper').height() < jQuery('#main').outerHeight()) {
	jQuery('#sidebar_wrapper').height(jQuery('#main').outerHeight());
	}
	else {
	body.height(jQuery('#sidebar_wrapper').outerHeight() - 60);
	}
	}
	});
	jQuery('.fontReset').click(function() {
	body.css('font-size', default_font_size + 'px');
	jQuery.removeCookie('font-size', { path: '/' });
	// Match sidebar_wrapper height with main height.
	if(body.outerWidth() > 767) {
	if(jQuery('#sidebar_wrapper').height() < jQuery('#main').outerHeight()) {
	jQuery('#sidebar_wrapper').height(jQuery('#main').outerHeight());
	}
	else {
	body.height(jQuery('#sidebar_wrapper').outerHeight() - 60);
	}
	}
	}); 
	
	// Header Search Placeholder.
	if(jQuery('#header_search input').length) {
		if(jQuery('#header_search input').val().length > 0) {
			jQuery('#header_search input').siblings('label').hide();
		}
		jQuery('#header_search input').keydown(function() {
			jQuery(this).siblings('label').hide();
		});
		jQuery('#header_search input').keyup(function() {
			if(jQuery(this).val().length > 0) {
				jQuery(this).siblings('label').hide();
			}
			else {
				jQuery(this).siblings('label').show();
			}
		});
		jQuery('#header_search input').focusout(function() {
			if(jQuery(this).val().length > 0) {
				jQuery(this).siblings('label').hide();
			}
			else {
				jQuery(this).siblings('label').show();
			}
		});
	}
	
	// Main Search Placeholder.
	if(jQuery('#main_search input').length) {
		if(jQuery('#main_search input').val().length > 0) {
			jQuery('#main_search input').siblings('label').hide();
		}
		jQuery('#main_search input').keydown(function() {
			jQuery(this).siblings('label').hide();
		});
		jQuery('#main_search input').keyup(function() {
			if(jQuery(this).val().length > 0) {
				jQuery(this).siblings('label').hide();
			}
			else {
				jQuery(this).siblings('label').show();
			}
		});
		jQuery('#main_search input').focusout(function() {
			if(jQuery(this).val().length > 0) {
				jQuery(this).siblings('label').hide();
			}
			else {
				jQuery(this).siblings('label').show();
			}
		});
	}

	// Navigation child width = parents width.
	if(body.outerWidth() > 767) {
		jQuery('#navigation ul li').each(function () {
		    jQuery(this).find('li a').width(jQuery(this).outerWidth(true));
		});
	}

	// Navigation.
//	jQuery('#navigation').find('a').not(":only-child").addClass('parent');
	
//	jQuery('.parent').click(function() {
//		if(jQuery(this).hasClass('drop')) {
//			jQuery(this).siblings('ul').slideUp(200);
//			jQuery(this).removeClass('drop');
//		}
//		else {
//			jQuery('.parent').siblings('ul').not(this).slideUp(200);
//			jQuery(this).parents('ul').css("display", "block");
//			jQuery(this).parents('li').eq(1).addClass('topmenu');
//			jQuery('#navigation').find('.topmenu').children('ul').slideDown(200);
//			jQuery('#navigation').find('li').children('a').removeClass('drop');
//			jQuery(this).siblings('ul').slideDown(200);
//			if(!jQuery(this).parent('li').parent('ul').parent('.menu').length > 0) {
//				jQuery(this).siblings('ul').css('left', jQuery(this).outerWidth());
//			}
//			jQuery(this).addClass('drop');
//		}
//		return false;
//	})
	
//	var t = null;
	
//	jQuery('#navigation').hover(function() {
//		if(t) { clearTimeout(t) };
//	}, function() {
//		t = setTimeout('slideup_nav()', 1000);
//	});
	
	// Navigation toggle in mobile
	jQuery('#nav_toggle').click(function() {
		if(jQuery('#navigation').hasClass('toggled')) {
			jQuery('#navigation').removeClass('toggled').slideUp(200);	
		}
		else {
			if(jQuery('#header_search').hasClass('toggled')) {
				jQuery('#header_search').removeClass('toggled').slideUp(200);
				jQuery('#main').animate({'margin-top': 0}, 200);
			}
			jQuery('#navigation').addClass('toggled').slideDown(200);
		}
	});
	
	// Search toggle in mobile
	jQuery('#search_toggle').click(function() {
		if(jQuery('#header_search').hasClass('toggled')) {
			jQuery('#header_search').removeClass('toggled').slideUp(200);
			jQuery('#main').animate({'margin-top': 0}, 200);
		}
		else {
			if(jQuery('#navigation').hasClass('toggled')) {
				jQuery('#navigation').removeClass('toggled').slideUp(200);
			}
			jQuery('#header_search').addClass('toggled').css('top', /* jQuery('#sliver').outerHeight() */ +  jQuery('.inner-header').outerHeight()).slideDown(200);
			jQuery('#main').animate({'margin-top': 100}, 200);
		}
	});
	
	// Hide announcer on "x" click and set cookie.
	jQuery('#announcer i').click(function() {
		jQuery.cookie('announcer_dismiss', true, { expires: 1 });
		jQuery('#announcer_wrapper').slideUp(200);
	})
	
	/*
	// Add widget column classes.
	jQuery('.widget_bar').each(function() {
		var count = jQuery(this).children('div.home_inner_widget').size();
		if(count == 1) {
			col = 'col12 last';
		}
		else if(count == 2) {
			col = 'col6';
		}
		else if(count == 3) {
			col = 'col4';
		}
		else if(count == 4) {
			col = 'col3';
		}
		jQuery(this).children('div.home_inner_widget').addClass(col);
		jQuery(this).children('div.home_inner_widget').last().addClass('last');
	});
	*/
	
	// Home Inner Widgets - Add link to title.
	jQuery('#home_inner_widgets .single-post-widget').each(function() {
		url = jQuery(this).attr('data-url');
		jQuery(this).siblings('.widgettitle').wrap('<a href="' + url + '"></a>');
	})
	
	// Calculate last footer widget cols.
//	jQuery('.footer_widget:last').addClass('last')
	
	// Disable tel link.
    jQuery('.tel a').click(function() {
		return false;
    });
    
    // Add icons to tel and email list items.
	// jQuery('.tel a').prepend('<i class="icon-phone"></i>');
	// jQuery('.email a').prepend('<i class="icon-envelope-alt"></i>');
	
	// Hide contact title.
	jQuery('.tel').parent('ul.list').parent('.footer_widget').removeClass('two-col').addClass('four-col');
	jQuery('.tel').parent('ul.list').siblings('h2').hide();
	jQuery('.email').parent('ul.list').parent('.footer_widget').removeClass('two-col').addClass('four-col');
	jQuery('.email').parent('ul.list').siblings('h2').hide();
	
	// Youtube Sidebar Widget.
	jQuery("#youtube-sidebar-widget li div.play_arrow, #youtube-sidebar-widget li a, .ysw-youtube").click(function(){
		if(jQuery(this).is(".ysw-youtube")) {
			var el = jQuery(this);
		} else {
			var el = jQuery(this).parent();
		}
		var hash = el.attr('id');
		if(el.is(".ysw-autoplay")) {
			var autoplay = 1;
		} else {
			var autoplay = el.attr('data-autoplay');
		}
		var ssl = document.location.protocol;
		jQuery('body').prepend("<div id='ysw-overlay'></div><div id='ysw-viewer'><a href='#'>close</a><iframe title='YouTube video player' width='640' height='390' src='" + ssl + "//www.youtube.com/embed/" + hash + "?autoplay=" + autoplay + "' frameborder='0' allowfullscreen></iframe></div>");
		var win = jQuery(window);
		var overlay = jQuery("#ysw-overlay");
		var viewer = jQuery('#ysw-viewer');
		var top = ((win.height() / 2) - (viewer.height() / 2)) + "px";
		var left = ((win.width() / 2) - (viewer.width() / 2)) + "px";
		viewer.css({
			top: top,
			left: left,
			display: 'block'
		}).children('a').click(function(){
			viewer.prev().hide().remove();
			viewer.hide().remove();
			return false;
		});
		overlay.css({
			left: "0px",
			top: "0px"
		});
		return false;
	});

	jQuery(window).resize(function() {
		var win = jQuery(window);
		var viewer = jQuery('#ysw-viewer');
		var top = ((win.height() / 2) - (viewer.height() / 2)) + "px";
		var left = ((win.width() / 2) - (viewer.width() / 2)) + "px";
		viewer.css({
			top: top,
			left: left,
			display: 'block'
		});
	});
});


/**********************************************************************
=change h2 to h3
**********************************************************************/
jQuery('#home_top_widgets h2.widgettitle').replaceWith(function() {
    jQuery(this).replaceWith('<h3 class="widgettitle">' + jQuery(this).text() + '</h3>');
});
jQuery('#home_bottom_widgets h2.widgettitle').replaceWith(function() {
    jQuery(this).replaceWith('<h3 class="widgettitle">' + jQuery(this).text() + '</h3>');
});
jQuery('#sidebar h2.widgettitle').replaceWith(function() {
    jQuery(this).replaceWith('<h3 class="widgettitle">' + jQuery(this).text() + '</h3>');
});

/**********************************************************************
=ON COMPLETE LOAD
**********************************************************************/

//jQuery(window).load(function() {
//	// Match sidebar_wrapper height with main height.
//	if(body.outerWidth() > 767) {
//		if(jQuery('#sidebar_wrapper').height() < jQuery('#main').outerHeight()) {
//			jQuery('#sidebar_wrapper').height(jQuery('#main').outerHeight());
//		}
//		else {
//			jQuery('#main').height(jQuery('#sidebar_wrapper').outerHeight() - 60);
//		}
//	}
//});
//
jQuery(window).load(function() {
// jQuery(window).resize(function() {
	// Match featured buttons height with slider.
	match_slider();
	 });
	 
       // if page has sidebar
jQuery(document).ready(function() {

	// if page has sidebar
	if (jQuery('#sidebar_wrapper').length > 0) { 
		jQuery("#main").addClass("wsidebar");
	} else {
	}

	// if home has sidebar
	if (jQuery('#sidebar_wrapper_home').length > 0) { 
		jQuery("#home_content_wrapper").addClass("wsidebar");
	} else {
	}

	// Match sidebar_wrapper height with main height.
//	if(body.outerWidth() > 767) {
//		if(jQuery('#sidebar_wrapper').height() < jQuery('#main').outerHeight()) {
//			jQuery('#sidebar_wrapper').height(jQuery('#main').outerHeight());
//		}
//		else {
//			jQuery('#main').height(jQuery('#sidebar_wrapper').outerHeight() - 40);
//		}
//
//	}
//	if(body.outerWidth() > 767) {
//		// Match sidebar_wrapper height with main height on home page.
//		if(jQuery('#sidebar_wrapper_home').height() < jQuery('#home_content_wrapper .second-row').outerHeight()) {
//			jQuery('#sidebar_wrapper_home').height(jQuery('#home_content_wrapper .second-row').outerHeight());
//		}
//		else {
//			jQuery('#home_content_wrapper .second-row').height(jQuery('#sidebar_wrapper_home').outerHeight());
//		}
//	}

});

/**********************************************************************
=FUNCTIONS
**********************************************************************/

// Nav function.
// function slideup_nav() {
//	jQuery('nav').find('.menu').children('ul').find('ul').delay(500).slideUp(200);
//	jQuery('nav').find('li').children('a').removeClass('drop');
// }

// Match featured buttons height with slider.
function match_slider() {
	if(body.outerWidth() > 767 && jQuery('#featured_slider #slides').length != 0) {
		jQuery('#featured_buttons ul li').each(function() {
			var height_calc = jQuery('#featured_slider #slides').height() / jQuery("#featured_buttons ul li").size();
			//jQuery(this).height(height_calc).css('line-height', (height_calc) + 'px');
			//jQuery(this).children('a').height(height_calc - 1).css('line-height', (height_calc) + 'px');
			//jQuery(this).stop().animate({'height': height_calc + 'px', 'line-height': (height_calc) + 'px'}, 200);
			jQuery(this).children('a').stop().animate({'height': (height_calc) + 'px', 'line-height': (height_calc) + 'px'}, 200);
		});
	}
}



/**********************************************************************
=ON COMPLETE LOAD
**********************************************************************/

onResize = function() {
	match_slider();
	// Match sidebar_wrapper height with main height.
//	if(body.outerWidth() > 767) {
//		if(jQuery('#sidebar_wrapper').height() < jQuery('#main').outerHeight()) {
//			jQuery('#sidebar_wrapper').height(jQuery('#main').outerHeight());
//		}
//		else {
//			jQuery('#main').height(jQuery('#sidebar_wrapper').outerHeight() - 40);
//		}
//	}

}

jQuery(window).load(onResize);
jQuery(window).bind('resize', onResize);