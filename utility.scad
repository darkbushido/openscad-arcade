/**
 * cutlines() - create an outline of a 2D object
 * line_width: Width of cut lines to draw.
 *
 * Note: this is useful for creating SVG dimension drawings, but not for
 * creating lasercutter output. This is used to prevent OpenSCAD SVG output
 * from just merging all objects into one large blob instead of distinct lines
 */
module cutlines(line_width=0.5)
{
	difference() {
		offset(delta=line_width) children();
		children();
	}
}

/**
 * round_corners() - Given a 2D shape, round off the corners to a given radius
 * r: radius of corner rounding.
 *
 * Rounds off the corners of a 2D shape by creating use of offsets. The
 * modifier first trims a depth of 'r' off all edges, then adds r*2 to get
 * rounding on the convex corners. Finally, it trims the edges again by 'r' to
 * round the concave corners.
 *
 * Note: any cutout or segment narrower than 2*r will disappear when this modifier
 * is appiled
 */
module round_corners(r)
{
	offset(r=-r) offset(r=r*2) offset(delta=-r) children();
}

/**
 * mirror_dup() - Place children twice, applying mirror() to one copy
 * v: vector of mirror plane
 *
 * Place two copies of children(). One unmodified, and one after applying the
 * mirror() modifier.
 */
module mirror_dup(v)
{
	children();
	mirror(v)
		children();
}

/**
 * fourcorners() - Utility for mirroring all children across the x & y planes
 *
 * Places 4 copies of children, mirrored across the x and y axies.
 */
module fourcorners()
{
	mirror_dup([0,1])
		mirror_dup([1,0])
			children();
}

/**
 * jigsaw_mask() - 2D Utility object for creating jigsaw cuts
 * size: size of mask object. Jigsaw profile will be on the left hand side
 * tcount: number of jigsaw teeth
 * tdepth: depth of jigsaw teeth
 * r: curve radius for smoothing
 */
module jigsaw_mask(size, tcount=7, tdepth=10, r=3)
{
	tsize = size.y/tcount/2;

	$fn=100;
	round_corners(r) {
		square(size);
		for (i = [0: tcount-1]) {
			translate([0, tsize * 2 * (i+0.5)])
				polygon([[-tdepth, -tsize/2-tdepth/4],
				         [-tdepth,  tsize/2+tdepth/4],
				         [0,     tsize/2-tdepth/4],
				         [0,    -tsize/2+tdepth/4]]);
		}
	}
}

module jigsaw_cut(y) {
	if (y) {
		translate([-15,0]) difference() {
			children();
			translate([y,-345]) jigsaw_mask([1000,350]);
		}
		translate ([15,0]) intersection() {
			children();
			translate([y,-345]) jigsaw_mask([1000,350]);
		}
	} else {
		children();
	}
}

jigsaw_mask([200,200]);
