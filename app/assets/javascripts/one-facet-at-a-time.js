$(function(){
    $('.facet_limit').on(
            'show.bs.collapse', // user clicked to show facet values...
            function(){
                $('.facet-content.collapse.in').collapse('hide');
                // ".in" identifies the facet currently open.
            }
    );
});
