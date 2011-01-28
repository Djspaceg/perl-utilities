<?php
require('UCFcommon.php');

/// Use this URL to activate the interface:
/// http://develop.lib.ucf.edu/cgi-bin/MapTiles.php?type=main2&export=1

/// Setup Global Constants
define( 'intZoomLevels',			5 );
define( 'intBaseZoomLevel',			0 );
define( 'intTileSize',				256 );
define( 'strMapDir',				Path('support') . 'Maps\\' );
define( 'strMapTileDir',			strMapDir . 'Tiles\\' );
define( 'strMapTileEmptyName',		strMapTileDir . 'empty.png' );
// define( 'strMapTileNameTemplate',	'z%z,%x,%y.jpg' );
define( 'strMapTileNameTemplate',	'z%z,%x,%y.png' );
// define( 'strBaseTilesDirWeb',	'/images/Maps/Tiles/' );

/// Setup Global Variables
$MAPTYPES = array(
	// 'main1'	=> 'LibMain1stFloorMedium.png',
	'main1'	=> 'LibMain1stFloor-01.png',
	// 'main2'	=> 'LibMain2ndFloorMedium.png',
	'main2'	=> 'LibMain2ndFloor-01.png',
	// 'main2new'	=> 'LibMain2ndFloorReno-01.png',
	// 'main3'	=> 'LibMain3rdFloorMedium.png',
	'main3'	=> 'LibMain3rdFloor-01.png',
	// 'main4'	=> 'LibMain4thFloorMedium.png',
	'main4'	=> 'LibMain4thFloor-01.png',
	// 'main4'	=> 'LibMain4thFloorBig.png',
	// 'main5'	=> 'LibMain5thFloorMedium.png',
	'main5'	=> 'LibMain5thFloor-01.png',
);

/// Grobal Derrived Variables
$strMapType = preg_replace('/\W/','', P('type') ? P('type') : '' );
if (!isset($MAPTYPES[ $strMapType ])) {
	die('Sorry. I don\'t recognize this map type. Try <a href="?type=main1">this</a>.'.$strMapType.P('maptype'));
}
$intZoomLevel = intval( preg_replace('/\D/','', P('zoom') ? P('zoom') : 0 ) );
$intX = intval( preg_replace('/[^\-\d]/','', P('x') ? P('x') : 0 ) );
$intY = intval( preg_replace('/[^\-\d]/','', P('y') ? P('y') : 0 ) );
$bitExport = P('export') ? 1 : 0;
$bitForceExport = P('force') ? 1 : 0;
$bitAllZoomLevels = P('alllevels') ? 1 : 0;

$strMapImagePath = strMapDir . $MAPTYPES[ $strMapType ];
$strMapTileDir = strMapTileDir . $strMapType . '\\';
$strMapTileName = GetTileName($intZoomLevel, $intX, $intY);
$strMapTilePath = $strMapTileDir . $strMapTileName;

/// Image Manipulation Globals
$imgMap = null;
$imgMapResized = null;
$colorBackground = Array(252, 248, 237);
$numScaleFactor = 0; //pow(2, intZoomLevels - $intZoomLevel);
$numLastZoomLevel = -1;


if ($bitExport) {
	/// Begin the export process for the given maptype
	UserInterface();
	if (P('empty')) {
		print '<h2>Generate Empty Tile</h2>';
		GenerateEmptyTile();
	}
	else {
		print '<h2>Processing Map '.$strMapType.'</h2>';
		if (file_exists($strMapImagePath)) {
			$size = getimagesize( $strMapImagePath );
			if ($size) {
				
				// print_r($size);
				
				// $intnewmapx = intval(2048 / $numScaleFactor);
				// $intnewmapy = intval(4096 / $numScaleFactor);
				// print '<p>Size X: '. $size[0] .' New Size X:'.($intnewmapx).'</p>';
				// print '<h3>Size X: '. 2048 .' ScalFactor: '.$numScaleFactor.' New Size X:'.($intnewmapx).'</h3>';
				
				// print '<br />Map Size: '.$intnewmapx.'x'.$intnewmapy.'<br />'.'<br />';
				// GenerateTile(2,3,4);
				// $f = fopen($strMapImagePath, 'rb');
				// if ($f) {
				for($z = 0; $z <= intZoomLevels; $z++) {
					if (!$bitAllZoomLevels) {
						$z = $intZoomLevel;
					}
					
					$numScaleFactor = pow(2, intZoomLevels - $z);
					$intnewmapx = intval($size[0] / $numScaleFactor);
					$intnewmapy = intval($size[1] / $numScaleFactor);
					
					print '<h3>Zoom Level '.$z.'</h3>';
					for($y = 0; ($y * intTileSize) <= $intnewmapy; $y++) {
						for($x = 0; ($x * intTileSize) <= $intnewmapx; $x++) {

							// print 'x'.($x*intTileSize).', y'.($y*intTileSize).'; ';
							// print ''.($x).','.($y).'; &nbsp;';
							GenerateTile($z,$x,$y);
						}
						// print '<br />';
					}
					if (!$bitAllZoomLevels) {
						$z = intZoomLevels+1;
					}
				}
				print '<h5>Finished processing</h5>';
				// }
			}
		}
	}
}
else {
	/// Just spit back the image that was requested
	$bittileexists = file_exists( $strMapTilePath );
	$bitemptytileexists = file_exists( strMapTileEmptyName );
	$strtilepath = '';
	if ( $bittileexists ) {
		$strtilepath = $strMapTilePath;
	}
	elseif ( $bitemptytileexists ) {
		$strtilepath = strMapTileEmptyName;
	}

	if ($strtilepath) {
		$size = getimagesize( $strtilepath );
		if ($size) {
			$fp = fopen($strtilepath, "rb");
			if ($fp) {
				// $date = new DateTime();
				// $date->add(new DateInterval('P10i'));
				// header('Content-type: text/html');
				// echo $strtilepath;
				// echo $date->format('Y-m-d') . "\n";
				$expireminutes = 10;
				$expireseconds = $expireminutes * 60;
				header('Content-type: '.$size['mime']);
				// header('Expires: '.date(DATE_RFC1123, time() + $expireseconds ));
				// header('Cache-Control: max-age='.$expireseconds);
				// header('Cache-Control: min-fresh='.$expireseconds);
				fpassthru($fp);
				exit;
			}
		}
		die('Sorry. I had trouble opening the tile file.');
	}
	die('Sorry. Map tile does not exist for the '.$intX.','.$intY.' tile coordinate in the '.$strMapType.' map type.');
}

exit;


/* Functions */

function P($var) {
	if (isset($_GET[$var])) {
		// if ($_GET[$var]) {
			return $_GET[$var];
		// }
		// return true;
	}
	return false;
}

function GetTileName($intzoomlevel, $intx, $inty) {
	$name = Token( strMapTileNameTemplate, 'z', sprintf('%02d', $intzoomlevel) );
	$name = Token( $name, 'x', $intx);
	$name = Token( $name, 'y', $inty);
	return $name;
}

function GenerateEmptyTile() {
	global $colorBackground;
	$imgtile = imagecreatetruecolor(intTileSize, intTileSize);
	$colorbackground = imagecolorallocate($imgtile, $colorBackground[0], $colorBackground[1], $colorBackground[2]);
	ImageFillAlpha($imgtile, $colorbackground);
	print '<div>Exported: '.strMapTileEmptyName.'</div>';
	imagepng($imgtile, strMapTileEmptyName, 9);
	imagedestroy($imgtile); 
}

function GenerateTile($z, $x, $y) {
	global $strMapType, $strMapImagePath, $strMapTileDir, $numScaleFactor, $imgMap, $imgMapResized, $bitForceExport, $colorBackground, $numLastZoomLevel;
	
	$strtilename = GetTileName($z, $x, $y);
	// print $strtilename.'<br/>';
	// return;
	print '<div class="ExportedImage">';
	if (file_exists($strMapTileDir.$strtilename) and !$bitForceExport) {
		print '<div>Skipping '.$strtilename.', already exists</div>';
		// return;
	}
	else {
		/// Generate the file
		// echo (MATRIXFULLSERVERPATH.' Doesn\'t exist.');
		$imgtile = imagecreatetruecolor(intTileSize, intTileSize);
		imagealphablending($imgtile, false);
		// $colortransparent = imagecolorallocatealpha($imgtile, 0, 0, 100, 127);
		// ImageFillAlpha($imgtile, $colortransparent);
		// imagesavealpha($destimage, true);
		// $black = imagecolorallocate($destimage, 0, 0, 0);
		
		//$mapsize = getimagesize( $strMapTilePath );
		if (!isset($imgMap)) {
			$imgMap = imagecreatefrompng($strMapImagePath);
			imagealphablending($imgMap, false);
			// $colortransparent = imagecolorallocatealpha($imgMap, 100, 0, 0, 50);
			// ImageFillAlpha($imgMap, $colortransparent);
		}
		
		$intnewmapx = intval(imagesx($imgMap) / $numScaleFactor);
		$intnewmapy = intval(imagesy($imgMap) / $numScaleFactor);
		if (!isset($imgMapResized) or $numLastZoomLevel != $z) {
			$resizedcanvasx = (intval($intnewmapx / intTileSize) * intTileSize ) + intTileSize;
			$resizedcanvasy = (intval($intnewmapy / intTileSize) * intTileSize ) + intTileSize;
			
			$imgMapResized = imagecreatetruecolor($resizedcanvasx, $resizedcanvasy);
			//imagealphablending($imgMapResized, false);
			//$colortransparent = imagecolorallocatealpha($imgMapResized, 0, 100, 0, 100);
			// $colorbackground = imagecolorallocate($imgMapResized, 229, 227, 223);
			$colorbackground = imagecolorallocate($imgMapResized, $colorBackground[0], $colorBackground[1], $colorBackground[2]);
			ImageFillAlpha($imgMapResized, $colorbackground);
			imagecopyresampled($imgMapResized, $imgMap, 0, 0, 0, 0, $intnewmapx, $intnewmapy, imagesx($imgMap), imagesy($imgMap));
			$numLastZoomLevel = $z;
		}
			// imagedestroy($imgmap);
		
		$imgtilenew = imagecreatetruecolor(intTileSize, intTileSize);
		imagealphablending($imgtilenew, false);
		// imagealphablending($tileimage, false);
		
		imagecopy( $imgtile, $imgMapResized, 0, 0, ($x * intTileSize), ($y * intTileSize), intTileSize, intTileSize );
		imagesettile($imgtile, $imgtilenew);
		imagedestroy($imgtilenew);
		
		// $edgefoundx = ( ($x * intTileSize)+intTileSize > $intnewmapx ) ? 1 : 0;
		// $edgefoundy = ( ($y * intTileSize)+intTileSize > $intnewmapy ) ? 1 : 0;
		// if ( $edgefoundx or $edgefoundy ) {
			// $relativemapright  = $edgefoundx ? (($intnewmapx-($x * intTileSize)) -1) : (($x * intTileSize)+intTileSize-1);
			// $relativemapbottom = $edgefoundy ? (($intnewmapy-($y * intTileSize)) -1) : (($y * intTileSize)+intTileSize-1);
			// $colortransparent = imagecolorallocatealpha($imgtile, 0, 255, 0, 100);
			// $colorborder = imagecolorallocate($imgtile, 0, 0, 0);
					// ImageFillAlpha($imgMapResized, $colortransparent);
					// imagealphablending($tileimage, false);
					// print (($x * intTileSize)+intTileSize-1) .' '. (($y * intTileSize)+intTileSize-1) . '; ' . $intnewmapx .' '. $intnewmapy.'; '.imagesx($imgMap) . ' ' .imagesy($imgMap);
					// imagefilltoborder($imgtile, ($x * intTileSize)-1, ($y * intTileSize)-1, $colorblock , $colortransparent );
					// $colorborder = imagecolorat ( $imgtile , $relativemapright, $relativemapbottom);
					// print (($x * intTileSize)+intTileSize-1) .' '. (($y * intTileSize)+intTileSize-1) . '; ' . $intnewmapx .' '. $intnewmapy.'; '.imagesx($imgMap) . ' ' .imagesy($imgMap);
			// print $relativemapright .' '. $relativemapbottom . '; ' . $intnewmapx .' '. $intnewmapy.'; '.imagesx($imgMap) . ' ' .imagesy($imgMap);
			// imagefilltoborder($imgtile, intTileSize-1, intTileSize-1, $colorborder , $colortransparent );
			// imagesetpixel ( $imgtile , $relativemapright , $relativemapbottom , imagecolorallocatealpha($imgtile, 255,0,0,0) );
			// imagesetpixel ( $imgtile , intTileSize-1, intTileSize-1, imagecolorallocatealpha($imgtile, 0,0,255,0) );
		// }
		imagesavealpha($imgtile, true);
		
		// $strtilename = preg_replace('/\.png$/', '.jpg', $strtilename );
		print '<div>Exported: '.$strtilename.'</div>';
		imagepng($imgtile, $strMapTileDir.$strtilename, 9);
		// imagejpeg($imgtile, $strMapTileDir.$strtilename, 90);
		imagedestroy($imgtile); 
	}
	// Output
	print '<img src="?type='.$strMapType.'&zoom='.$z.'&x='.$x.'&y='.$y.'" alt="'.$strMapTileDir.$strtilename.'" /></div>';
}


function ImageFillAlpha($image, $color) {
	imagefilledrectangle($image, 0, 0, imagesx($image), imagesy($image), $color);
}

function UserInterface() {
	global $MAPTYPES;
	?>
<style type="text/css">
body {
	font-family: "Gill Sans", "Gill Sans MT", Verdana, sans-serif;
	font-size: 0.8em;
}
h4 {
	text-align: center;
}
h1, h2, h3, h4, h5, h6 {
	clear: both;
	width: 100%;
	overflow: hidden;
}
.ExportedImage {
	float: left;
	border: 1px dashed #ccc;
	margin: 2px;
	width: 256px;
	height: 276px;
}
.ExportedImage div {
	line-height: 20px;
	color: #333;
	background-color: #eee;
	border-bottom: 1px dashed #ccc;
}
</style>
<p><a href="?type=main1&export=1&empty=1">Generate Empty Tile</a></p>
<table>
	<tbody>
		<tr>
	<?
	foreach ($MAPTYPES as $type => $mapname) {
	$MAPTYPES
	?>
			<td>
				<h4><?=$type ?> <a href="?type=<?=$type ?>&zoom=<?=$z ?>&export=1&alllevels=1">all</a> <a href="?type=<?=$type ?>&zoom=<?=$z ?>&export=1&force=1&alllevels=1">force all</a></h4>
				<ul>
	<?
	for ($z = 0; $z <= intBaseZoomLevel + intZoomLevels; $z++) {
	?>
					<li><a href="?type=<?=$type ?>&zoom=<?=$z ?>&export=1">Zoom Level <?=$z ?></a> <a href="?type=<?=$type ?>&zoom=<?=$z ?>&export=1&force=1">force</a></li>
	<?
	}
	?>
				</ul>
			</td>
	<?
	}
	?>
		</tr>
	</tbody>
</table>
	<?
}

?>
