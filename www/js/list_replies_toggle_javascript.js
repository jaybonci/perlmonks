function toggleReply ( replyID )
{
  rr = document.getElementById( 'rr' + replyID );
  if ( rr ) {
    if ( rr.style.display == 'none' ) {
      rr.style.display = '';
    } else {
      rr.style.display = 'none';
    }
  }
}

function doNothing () { }

