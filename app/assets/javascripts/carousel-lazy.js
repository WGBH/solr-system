$(function(){
    $('body').on('slide.bs.carousel', function(e) {
        var $target = $(e.relatedTarget);
        
        var $next_next_img = $target.next().find('img');
        $next_next_img.attr('src', $next_next_img.attr('data-lazy-src'));
        
        var $prev_prev_img = $target.prev().find('img');
        $prev_prev_img.attr('src', $prev_prev_img.attr('data-lazy-src'));
        // No harm done if src is already set, or if we're at the end of the list.
        // (If we only do the immediate "next", it hasn't actually loaded when the swap happens.) 
    }); 
});
