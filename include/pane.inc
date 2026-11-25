// pane tree of a tab: leaves hold one view, splits hold two children side by side or stacked
// rects are computed by av_pane_layout in a y-down space (the container view is flipped)

.set P_PARENT, 0
.set P_KIND,   8
.set P_NSVIEW, 16              // leaf
.set P_VIEW,   24              // leaf: View * for editors, Term * for terminals
.set P_DOC,    32              // leaf: Doc *, 0 for terminals
.set P_A,      16              // split: left or top child
.set P_B,      24              // split: right or bottom child
.set P_RATIO,  32              // split: share of the first child, double
.set P_X,      40
.set P_Y,      48
.set P_W,      56
.set P_H,      64
.set P_SIZE,   80

.set PK_EDITOR,   1
.set PK_TERMINAL, 2
.set PK_ROW,      3            // children left | right
.set PK_COL,      4            // children top / bottom

.set PANE_GAP, 1               // divider width in points

.set DIR_LEFT,  0
.set DIR_RIGHT, 1
.set DIR_UP,    2
.set DIR_DOWN,  3
