package MySQL::Monitor;

use 5.16.2;
use strict;
use warnings FATAL => 'all';
use Getopt::Long;
use DBI;
use Term::ReadKey;
use Smart::Comments;
use List::MoreUtils qw(any);
use Net::Domain qw(hostname hostfqdn);
use Cwd qw(abs_path);
use File::Mountpoint qw(is_mountpoint);
use File::Basename qw(dirname);
use Filesys::DfPortable;

=head1 NAME

MySQL::Monitor - Monitor mysql status and customed status

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

mysqlmonitor is a script to monitor mysql status and customed status which is a perl clone of mycheckpoint L<code.openark.org/forge/mycheckpoint>.
Perhaps a little code snippet.

=cut

# global variables
my %options = 
  (
   "user"=> "",
   "host"=> "localhost",
   "password"=> "",
   "prompt_password"=> 0,
   "port"=> 3306,
   "socket"=> "/var/run/mysqld/mysql.sock",
   "monitored_host"=> undef,
   "monitored_port"=> 3306,
   "monitored_socket"=> undef,
   "monitored_user"=> undef,
   "monitored_password"=> undef,
   "defaults_file"=> "",
   "database"=> "mycheckpoint",
   "skip_aggregation"=> 0,
   "rebuild_aggregation"=> 0,
   "purge_days"=> 182,
   "disable_bin_log"=> 0,
   "skip_check_replication"=> 0,
   "force_os_monitoring"=> 0,
   "skip_alerts"=> 0,
   "skip_emails"=> 0,
   "force_emails"=> 0,
   "skip_custom"=> 0,
   "skip_defaults_file"=> 0,
   "chart_width"=> 370,
   "chart_height"=> 180,
   "chart_service_url"=> "http=>//chart.apis.google.com/chart",
   "smtp_host"=> undef,
   "smtp_from"=> undef,
   "smtp_to"=> undef,
   "http_port"=> 12306,
   "debug"=> 0,
   "verbose"=> 0,
   "version"=> 0,
  );

my $database_name;
my $table_name = "status_variables";

my ($args, %action, $monitored_conn, $write_conn, %status_dict, %extra_dict, @custom_query_ids);

my $help_msg = <<HELP;
Usage: mysqlmonitor [options] [command [, command ...]]

mysqlmonitor is a script to monitor mysql status and customed status which is a perl clone of mycheckpoint L<code.openark.org/forge/mycheckpoint>.

See online documentation on L<http://code.openark.org/forge/mycheckpoint/documentation>

Available commands:
  http
  deploy
  email_brief_report

Options:
  -h, --help            show this help message and exit
  -u USER, --user=USER  MySQL user
  -H HOST, --host=HOST  MySQL host. Written to by this application (default:
                        localhost)
  -p PASSWORD, --password=PASSWORD
                        MySQL password
  --ask-pass            Prompt for password
  -P PORT, --port=PORT  TCP/IP port (default: 3306)
  -S SOCKET, --socket=SOCKET
                        MySQL socket file. Only applies when host is localhost
                        (default: /var/run/mysqld/mysql.sock)
  --monitored-host=MONITORED_HOST
                        MySQL monitored host. Specity this when the host
                        you're monitoring is not the same one you're writing
                        to (default: none, host specified by --host is both
                        monitored and written to)
  --monitored-port=MONITORED_PORT
                        Monitored host's TCP/IP port (default: 3306). Only
                        applies when monitored-host is specified
  --monitored-socket=MONITORED_SOCKET
                        Monitored host MySQL socket file. Only applies when
                        monitored-host is specified and is localhost (default:
                        /var/run/mysqld/mysql.sock)
  --monitored-user=MONITORED_USER
                        MySQL monitored server user name. Only applies when
                        monitored-host is specified (default: same as user)
  --monitored-password=MONITORED_PASSWORD
                        MySQL monitored server password. Only applies when
                        monitored-host is specified (default: same as
                        password)
  --defaults-file=DEFAULTS_FILE
                        Read from MySQL configuration file. Overrides all
                        other options
  -d DATABASE, --database=DATABASE
                        Database name (required unless query uses fully
                        qualified table names)
  --skip-aggregation    Skip creating and maintaining aggregation tables
  --rebuild-aggregation
                        Completely rebuild (drop, create and populate)
                        aggregation tables upon deploy
  --purge-days=PURGE_DAYS
                        Purge data older than specified amount of days
                        (default: 182)
  --disable-bin-log     Disable binary logging (binary logging enabled by
                        default)
  --skip-disable-bin-log
                        Skip disabling the binary logging (this is default
                        behaviour; binary logging enabled by default)
  --skip-check-replication
                        Skip checking on master/slave status variables
  -o, --force-os-monitoring
                        Monitor OS even if monitored host does does nto appear
                        to be the local host. Use when you are certain the
                        monitored host is local
  --skip-alerts         Skip evaluating alert conditions as well as sending
                        email notifications
  --skip-emails         Skip sending email notifications
  --force-emails        Force sending email notifications even if there's
                        nothing wrong
  --skip-custom         Skip custom query execution and evaluation
  --skip-defaults-file  Do not read defaults file. Overrides --defaults-file
                        and ignores /etc/mycheckpoint.cnf
  --chart-width=CHART_WIDTH
                        Chart image width (default: 370, min value: 150)
  --chart-height=CHART_HEIGHT
                        Chart image height (default: 180, min value: 100)
  --chart-service-url=CHART_SERVICE_URL
                        Url to Google charts API (default:
                        http://chart.apis.google.com/chart)
  --smtp-host=SMTP_HOST
                        SMTP mail server host name or IP
  --smtp-from=SMTP_FROM
                        Address to use as mail sender
  --smtp-to=SMTP_TO     Comma delimited email addresses to send emails to
  --http-port=HTTP_PORT
                        Socket to listen on when running as web server
                        (argument is http)
  --debug               Print stack trace on error
  -v, --verbose         Print user friendly messages
  --version             Prompt version number
HELP


my $openark_lchart = <<'LCHART';
    openark_lchart=function(a,b){if(a.style.width==""){this.canvas_width=b.width}else{this.canvas_width=a.style.width}if(a.style.height==""){this.canvas_height=b.height}else{this.canvas_height=a.style.height}this.title_height=0;this.chart_title="";this.x_axis_values_height=20;this.y_axis_values_width=50;this.y_axis_tick_values=[];this.y_axis_tick_positions=[];this.x_axis_grid_positions=[];this.x_axis_label_positions=[];this.x_axis_labels=[];this.y_axis_min=0;this.y_axis_max=0;this.y_axis_round_digits=0;this.multi_series=[];this.multi_series_dot_positions=[];this.series_labels=[];this.series_legend_values=[];this.timestamp_legend_value=null;this.series_colors=openark_lchart.series_colors;this.tsstart=null;this.tsstep=null;this.container=a;this.interactive_legend=null;this.legend_values_containers=[];this.timestamp_value_container=null;this.canvas_shadow=null;this.position_pointer=null;this.isIE=false;this.current_color=null;this.skip_interactive=false;if(b.skipInteractive){this.skip_interactive=true}this.recalc();return this};openark_lchart.title_font_size=10;openark_lchart.title_color="#505050";openark_lchart.axis_color="#707070";openark_lchart.axis_font_size=8;openark_lchart.min_x_label_spacing=32;openark_lchart.legend_font_size=9;openark_lchart.legend_color="#606060";openark_lchart.series_line_width=1.5;openark_lchart.grid_color="#e4e4e4";openark_lchart.grid_thick_color="#c8c8c8";openark_lchart.position_pointer_color="#808080";openark_lchart.series_colors=["#ff0000","#ff8c00","#4682b4","#9acd32","#dc143c","#9932cc","#ffd700","#191970","#7fffd4","#808080","#dda0dd"];openark_lchart.google_simple_format_scheme="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";openark_lchart.prototype.recalc=function(){this.chart_width=this.canvas_width-this.y_axis_values_width;this.chart_height=this.canvas_height-(this.x_axis_values_height+this.title_height);this.chart_origin_x=this.canvas_width-this.chart_width;this.chart_origin_y=this.title_height+this.chart_height;this.y_axis_tick_values=[];this.y_axis_tick_positions=[];if(this.y_axis_max<=this.y_axis_min){return}max_steps=Math.floor(this.chart_height/(openark_lchart.axis_font_size*1.6));round_steps_basis=[1,2,5];step_size=null;pow=0;for(power=-4;power<10&&!step_size;++power){for(i=0;i<round_steps_basis.length&&!step_size;++i){round_step=round_steps_basis[i]*Math.pow(10,power);if((this.y_axis_max-this.y_axis_min)/round_step<max_steps){step_size=round_step;pow=power}}}var c=step_size*Math.ceil(this.y_axis_min/step_size);while(c<=this.y_axis_max){var b=(pow>=0?c:c.toFixed(-pow));this.y_axis_tick_values.push(b);var a=(c-this.y_axis_min)/(this.y_axis_max-this.y_axis_min);this.y_axis_tick_positions.push(Math.floor(this.chart_origin_y-a*this.chart_height));c+=step_size}this.y_axis_round_digits=(pow>=0?0:-pow)};openark_lchart.prototype.create_graphics=function(){this.container.innerHTML="";this.isIE=(/MSIE/.test(navigator.userAgent)&&!window.opera);this.container.style.position="relative";this.container.style.color=""+openark_lchart.axis_color;this.container.style.fontSize=""+openark_lchart.axis_font_size+"pt";this.container.style.fontFamily="Helvetica,Verdana,Arial,sans-serif";if(!this.skip_interactive){var b=this;this.container.onmousemove=function(c){b.on_mouse_move(c)};this.container.onmouseout=function(c){b.on_mouse_out(c)}}if(this.isIE){}else{var a=document.createElement("canvas");a.setAttribute("width",this.canvas_width);a.setAttribute("height",this.canvas_height);this.canvas=a;this.container.appendChild(this.canvas);this.ctx=this.canvas.getContext("2d")}this.canvas_shadow=document.createElement("div");this.canvas_shadow.style.position="absolute";this.canvas_shadow.style.top="0";this.canvas_shadow.style.left="0";this.canvas_shadow.style.width=this.canvas_width;this.canvas_shadow.style.height=this.canvas_height;this.container.appendChild(this.canvas_shadow)};openark_lchart.prototype.parse_url=function(a){a=a.replace(/[+]/gi," ");var b={};var c=a.indexOf("?");if(c>=0){a=a.substring(c+1)}tokens=a.split("&");for(i=0;i<tokens.length;++i){param_tokens=tokens[i].split("=");if(param_tokens.length==2){b[param_tokens[0]]=param_tokens[1]}}return b};openark_lchart.prototype.read_google_url=function(f){params=this.parse_url(f);this.title_height=0;if(params.chtt){this.chart_title=params.chtt;this.title_height=20}if(params.chdl){var j=params.chdl.split("|");this.series_labels=j}if(params.chco){var j=params.chco.split(",");this.series_colors=new Array(j.length);for(i=0;i<j.length;++i){this.series_colors[i]="#"+j[i]}}var j=params.chxr.split(",");if(j.length>=3){this.y_axis_min=parseFloat(j[1]);this.y_axis_max=parseFloat(j[2])}this.recalc();var j=params.chg.split(",");if(j.length>=6){var t=parseFloat(j[0]);var k=parseFloat(j[4]);this.x_axis_grid_positions=[];for(i=0,chart_x_pos=0;chart_x_pos<this.chart_width;++i){chart_x_pos=(k+i*t)*this.chart_width/100;if(chart_x_pos<this.chart_width){this.x_axis_grid_positions.push(Math.floor(chart_x_pos+this.chart_origin_x))}}}var j=params.chxp.split("|");for(axis=0;axis<j.length;++axis){var n=j[axis].split(",");var e=parseInt(n[0]);if(e==0){this.x_axis_label_positions=new Array(n.length-1);for(i=1;i<n.length;++i){var l=parseFloat(n[i])*this.chart_width/100;this.x_axis_label_positions[i-1]=Math.floor(l+this.chart_origin_x)}}}var j=params.chxl.split("|");if(j[0]=="0:"){this.x_axis_labels=new Array(j.length-1);for(i=1;i<j.length;++i){this.x_axis_labels[i-1]=j[i]}}if(params.chd){var a=params.chd;var g=null;var d=a.substring(0,2);if(d=="s:"){g="simple"}else{if(d=="t:"){g="text"}}if(g){this.multi_series=[];this.multi_series_dot_positions=[]}if(g=="simple"){this.skip_interactive=true;a=a.substring(2);var j=a.split(",");this.multi_series=new Array(j.length);this.multi_series_dot_positions=new Array(j.length);for(series_index=0;series_index<j.length;++series_index){var c=j[series_index];var h=new Array(c.length);var r=new Array(c.length);for(i=0;i<c.length;++i){var s=c.charAt(i);if(s=="_"){h[i]=null;r[i]=null}else{var m=openark_lchart.google_simple_format_scheme.indexOf(s)/61;var b=this.y_axis_min+m*(this.y_axis_max-this.y_axis_min);h[i]=b;r[i]=Math.round(this.chart_origin_y-m*this.chart_height)}}this.multi_series[series_index]=h;this.multi_series_dot_positions[series_index]=r}}if(g=="text"){a=a.substring(2);var j=a.split("|");this.multi_series=new Array(j.length);this.multi_series_dot_positions=new Array(j.length);for(series_index=0;series_index<j.length;++series_index){var q=j[series_index];var o=q.split(",");var h=new Array(o.length);var r=new Array(o.length);for(i=0;i<o.length;++i){var p=o[i];if(p=="_"){h[i]=null;r[i]=null}else{h[i]=parseFloat(p);var m=0;if(this.y_axis_max>this.y_axis_min){if(h[i]<this.y_axis_min){m=0}else{if(h[i]>this.y_axis_max){m=1}else{m=(h[i]-this.y_axis_min)/(this.y_axis_max-this.y_axis_min)}}}r[i]=Math.round(this.chart_origin_y-m*this.chart_height)}}this.multi_series[series_index]=h;this.multi_series_dot_positions[series_index]=r}}}if(params.tsstart){tsstart_text=params.tsstart.replace(/-/g,"/");this.tsstart=new Date(tsstart_text)}if(params.tsstep){this.tsstep=parseInt(params.tsstep)}this.redraw()};openark_lchart.prototype.redraw=function(){this.create_graphics();this.draw()};openark_lchart.prototype.create_value_container=function(){var a=document.createElement("div");a.style.display="inline";a.style.position="absolute";a.style.right=""+0+"px";a.style.textAlign="right";a.style.fontWeight="bold";return a};openark_lchart.prototype.draw=function(){if(this.chart_title){var n={text:this.chart_title,left:0,top:0,width:this.canvas_width,height:this.title_height,text_align:"center",font_size:openark_lchart.title_font_size};if(this.chart_title.search("STALE DATA")>=0){n.background="#ffcccc"}this.draw_text(n)}this.set_color(openark_lchart.grid_color);for(i=0;i<this.y_axis_tick_positions.length;++i){this.draw_line(this.chart_origin_x,this.y_axis_tick_positions[i],this.chart_origin_x+this.chart_width-1,this.y_axis_tick_positions[i],1)}for(i=0;i<this.x_axis_grid_positions.length;++i){if(this.x_axis_labels[i].replace(/ /gi,"")){this.set_color(openark_lchart.grid_thick_color)}else{this.set_color(openark_lchart.grid_color)}this.draw_line(this.x_axis_grid_positions[i],this.chart_origin_y,this.x_axis_grid_positions[i],this.chart_origin_y-this.chart_height+1,1)}this.set_color(openark_lchart.axis_color);var k=0;for(i=0;i<this.x_axis_label_positions.length;++i){var g=this.x_axis_labels[i];var h=g.replace(/ /gi,"");if(g&&((k==0)||(this.x_axis_label_positions[i]-k>=openark_lchart.min_x_label_spacing)||!h)){this.draw_line(this.x_axis_label_positions[i],this.chart_origin_y,this.x_axis_label_positions[i],this.chart_origin_y+3,1);if(h){this.draw_text({text:""+g,left:this.x_axis_label_positions[i]-25,top:this.chart_origin_y+5,width:50,height:openark_lchart.axis_font_size,text_align:"center",font_size:openark_lchart.axis_font_size});k=this.x_axis_label_positions[i]}}}for(series=0;series<this.multi_series_dot_positions.length;++series){var l=[];l.push([]);this.set_color(this.series_colors[series]);var m=this.multi_series_dot_positions[series];for(i=0;i<m.length;++i){if(m[i]==null){l.push([])}else{var e=Math.round(this.chart_origin_x+i*this.chart_width/(m.length-1));l[l.length-1].push({x:e,y:m[i]})}}for(path=0;path<l.length;++path){this.draw_line_path(l[path],openark_lchart.series_line_width)}}this.set_color(openark_lchart.axis_color);this.draw_line(this.chart_origin_x,this.chart_origin_y,this.chart_origin_x,this.chart_origin_y-this.chart_height+1,1);this.draw_line(this.chart_origin_x,this.chart_origin_y,this.chart_origin_x+this.chart_width-1,this.chart_origin_y,1);var b="";for(i=0;i<this.y_axis_tick_positions.length;++i){this.draw_line(this.chart_origin_x,this.y_axis_tick_positions[i],this.chart_origin_x-3,this.y_axis_tick_positions[i],1);this.draw_text({text:""+this.y_axis_tick_values[i],left:0,top:this.y_axis_tick_positions[i]-openark_lchart.axis_font_size+Math.floor(openark_lchart.axis_font_size/3),width:this.y_axis_values_width-5,height:openark_lchart.axis_font_size,text_align:"right",font_size:openark_lchart.axis_font_size})}if(this.series_labels&&this.series_labels.length){if(this.isIE){var j=document.createElement("div");j.style.width=this.canvas_width;j.style.height=this.canvas_height;this.container.appendChild(j)}var f=document.createElement("div");var a=document.createElement("ul");a.style.margin=0;a.style.paddingLeft=this.chart_origin_x;if(this.tsstart){var c=document.createElement("li");c.style.listStyleType="none";c.style.fontSize=""+openark_lchart.legend_font_size+"pt";c.innerHTML="&nbsp;";this.timestamp_value_container=this.create_value_container();c.appendChild(this.timestamp_value_container);a.appendChild(c)}for(i=0;i<this.series_labels.length;++i){var c=document.createElement("li");c.style.listStyleType="square";c.style.color=this.series_colors[i];c.style.fontSize=""+openark_lchart.legend_font_size+"pt";c.innerHTML='<span style="color: '+openark_lchart.legend_color+'">'+this.series_labels[i]+"</span>";var d=this.create_value_container();d.style.width=""+(this.chart_origin_x+32)+"px";c.appendChild(d);this.legend_values_containers.push(d);a.appendChild(c)}f.appendChild(a);this.container.appendChild(f);this.interactive_legend=document.createElement("ul");this.interactive_legend.style.position="relative";this.interactive_legend.style.right="0px";this.interactive_legend.style.top="0px";f.appendChild(this.interactive_legend)}};openark_lchart.prototype.set_color=function(a){this.current_color=a;if(!this.isIE){this.ctx.strokeStyle=a}};openark_lchart.prototype.draw_line=function(d,f,c,e,a){if(this.isIE){var b=document.createElement("v:line");b.setAttribute("from"," "+d+" "+f+" ");b.setAttribute("to"," "+c+" "+e+" ");b.setAttribute("strokecolor",""+this.current_color);b.setAttribute("strokeweight",""+a+"pt");this.container.appendChild(b)}else{this.ctx.lineWidth=a;this.ctx.strokeWidth=0.5;this.ctx.beginPath();this.ctx.moveTo(d+0.5,f+0.5);this.ctx.lineTo(c+0.5,e+0.5);this.ctx.closePath();this.ctx.stroke()}};openark_lchart.prototype.draw_line_path=function(e,a){if(e.length==0){return}if(e.length==1){this.draw_line(e[0].x-2,e[0].y,e[0].x+2,e[0].y,a*0.8);this.draw_line(e[0].x,e[0].y-2,e[0].x,e[0].y+2,a*0.8);return}if(this.isIE){var c=document.createElement("v:polyline");var b=new Array(e.length*2);for(i=0;i<e.length;++i){b[i*2]=e[i].x;b[i*2+1]=e[i].y}var d=b.join(",");c.setAttribute("points",d);c.setAttribute("stroked","true");c.setAttribute("filled","false");c.setAttribute("strokecolor",""+this.current_color);c.setAttribute("strokeweight",""+a+"pt");this.container.appendChild(c)}else{this.ctx.lineWidth=a;this.ctx.strokeWidth=0.5;this.ctx.beginPath();this.ctx.moveTo(e[0].x+0.5,e[0].y+0.5);for(i=1;i<e.length;++i){this.ctx.lineTo(e[i].x+0.5,e[i].y+0.5)}this.ctx.stroke()}};openark_lchart.prototype.draw_text=function(b){var a=document.createElement("div");a.style.position="absolute";a.style.left=""+b.left+"px";a.style.top=""+b.top+"px";a.style.width=""+b.width+"px";a.style.height=""+b.height+"px";a.style.textAlign=""+b.text_align;a.style.verticalAlign="top";if(b.font_size){a.style.fontSize=""+b.font_size+"pt"}if(b.background){a.style.background=""+b.background}a.innerHTML=b.text;this.container.appendChild(a)};openark_lchart.prototype.on_mouse_move=function(a){if(!a){var a=window.event}var h=a.clientX-(findPosX(this.container)-(window.pageXOffset||document.documentElement.scrollLeft||document.body.scrollLeft||0));var g=a.clientY-(findPosY(this.container)-(window.pageYOffset||document.documentElement.scrollTop||document.body.scrollTop||0));var c=h-this.chart_origin_x;var b=this.chart_origin_y-g;var e=((c<=this.chart_width)&&(b<=this.chart_height)&&(c>=0)&&(b>=-20));var l=Math.round((this.multi_series[0].length-1)*(c/this.chart_width));if((b<0)&&(b>=-20)&&(c>=this.chart_width-10)){l=this.multi_series[0].length-1}if(e){this.series_legend_values=new Array(this.multi_series.length);for(series=0;series<this.multi_series.length;++series){var j=this.multi_series[series][l];if(j==null){this.series_legend_values[series]="n/a"}else{this.series_legend_values[series]=j.toFixed(this.y_axis_round_digits+1)}}if(this.position_pointer==null){this.position_pointer=document.createElement("div");this.position_pointer.style.position="absolute";this.position_pointer.style.top=""+(this.chart_origin_y-this.chart_height)+"px";this.position_pointer.style.width="2px";this.position_pointer.style.filter="alpha(opacity=60)";this.position_pointer.style.opacity="0.6";this.position_pointer.style.height=""+(this.chart_height)+"px";this.position_pointer.style.backgroundColor=openark_lchart.position_pointer_color;this.canvas_shadow.appendChild(this.position_pointer)}if(this.tsstart){var k=new Date(this.tsstart);if(this.tsstep%(60*60*24)==0){k.setDate(this.tsstart.getDate()+(this.tsstep/(60*60*24))*l)}else{if(this.tsstep%(60*60)==0){k.setHours(this.tsstart.getHours()+(this.tsstep/(60*60))*l)}else{if(this.tsstep%(60)==0){k.setMinutes(this.tsstart.getMinutes()+(this.tsstep/(60))*l)}else{k.setSeconds(this.tsstart.getSeconds()+this.tsstep*l)}}}var d=(this.tsstep<60*60*24);this.timestamp_legend_value=format_date(k,d)}this.update_legend();var f=Math.floor(this.chart_origin_x+l*this.chart_width/(this.multi_series_dot_positions[0].length-1));this.position_pointer.style.visibility="visible";this.position_pointer.style.left=""+(f)+"px"}else{this.clear_position_pointer_and_legend_values(a)}};openark_lchart.prototype.on_mouse_out=function(a){if(!a){var a=window.event}if(a.relatedTarget==this.position_pointer){return}this.clear_position_pointer_and_legend_values(a)};openark_lchart.prototype.clear_position_pointer_and_legend_values=function(a){if(this.position_pointer!=null){this.position_pointer.style.visibility="hidden"}this.series_legend_values=null;this.update_legend()};openark_lchart.prototype.update_legend=function(){if(this.tsstart){if(this.series_legend_values==null){this.timestamp_value_container.innerHTML=""}else{this.timestamp_value_container.innerHTML=this.timestamp_legend_value.replace(/ /g,"&nbsp;")}}for(i=0;i<this.series_labels.length;++i){if(this.series_legend_values==null){this.legend_values_containers[i].innerHTML=""}else{var a=0;if(this.y_axis_min<this.y_axis_max){a=100*((this.series_legend_values[i]-this.y_axis_min)/(this.y_axis_max-this.y_axis_min))}this.legend_values_containers[i].innerHTML=""+this.series_legend_values[i]}}};function findPosX(a){var b=0;if(a.offsetParent){while(1){b+=a.offsetLeft;if(!a.offsetParent){break}a=a.offsetParent}}else{if(a.x){b+=a.x}}return b}function findPosY(b){var a=0;if(b.offsetParent){while(1){a+=b.offsetTop;if(!b.offsetParent){break}b=b.offsetParent}}else{if(b.y){a+=b.y}}return a}function format_date(c,b){pad=function(f,e){var d=""+f;while(d.length<e){d="0"+d}return d};var a=""+c.getFullYear()+"-"+pad(c.getMonth()+1,2)+"-"+pad(c.getDate(),2);if(b){a+=" "+pad(c.getHours(),2)+":"+pad(c.getMinutes(),2)}return a};
LCHART

my $openark_schart = <<'SCHART';
    openark_schart=function(a,b){if(a.style.width==""){this.canvas_width=b.width}else{this.canvas_width=a.style.width}if(a.style.height==""){this.canvas_height=b.height}else{this.canvas_height=a.style.height}this.title_height=0;this.chart_title="";this.x_axis_values_height=30;this.y_axis_values_width=35;this.x_axis_labels=[];this.x_axis_label_positions=[];this.y_axis_labels=[];this.y_axis_label_positions=[];this.dot_x_positions=[];this.dot_y_positions=[];this.dot_values=[];this.dot_colors=[];this.plot_colors=openark_schart.plot_colors;this.container=a;this.isIE=false;this.current_color=null;this.recalc();return this};openark_schart.title_font_size=10;openark_schart.title_color="#505050";openark_schart.axis_color="#707070";openark_schart.axis_font_size=8;openark_schart.plot_colors=["#9aed32","#ff8c00"];openark_schart.max_dot_size=9;openark_schart.prototype.recalc=function(){this.chart_width=this.canvas_width-this.y_axis_values_width-openark_schart.max_dot_size;this.chart_height=this.canvas_height-(this.x_axis_values_height+this.title_height)-openark_schart.max_dot_size;this.chart_origin_x=this.y_axis_values_width;this.chart_origin_y=this.canvas_height-this.x_axis_values_height};openark_schart.prototype.create_graphics=function(){this.container.innerHTML="";this.isIE=(/MSIE/.test(navigator.userAgent)&&!window.opera);this.container.style.position="relative";this.container.style.color=""+openark_schart.axis_color;this.container.style.fontSize=""+openark_schart.axis_font_size+"pt";this.container.style.fontFamily="Helvetica,Verdana,Arial,sans-serif";if(this.isIE){var b=document.createElement("div");b.style.width=this.canvas_width;b.style.height=this.canvas_height;this.container.appendChild(b)}else{var a=document.createElement("canvas");a.setAttribute("width",this.canvas_width);a.setAttribute("height",this.canvas_height);this.canvas=a;this.container.appendChild(this.canvas);this.ctx=this.canvas.getContext("2d")}};openark_schart.prototype.hex_to_rgb=function(b){if(b.substring(0,1)=="#"){b=b.substring(1)}var a=[];b.replace(/(..)/g,function(c){a.push(parseInt(c,16))});return a};openark_schart.prototype.toHex=function(a){if(a==0){return"00"}return"0123456789abcdef".charAt((a-a%16)/16)+"0123456789abcdef".charAt(a%16)};openark_schart.prototype.rgb_to_hex=function(c,b,a){return"#"+this.toHex(c)+this.toHex(b)+this.toHex(a)};openark_schart.prototype.gradient=function(c,b,a){var e=this.hex_to_rgb(c);var d=this.hex_to_rgb(b);return this.rgb_to_hex(Math.floor(e[0]+(d[0]-e[0])*a/100),Math.floor(e[1]+(d[1]-e[1])*a/100),Math.floor(e[2]+(d[2]-e[2])*a/100))};openark_schart.prototype.parse_url=function(a){a=a.replace(/[+]/gi," ");var b={};var c=a.indexOf("?");if(c>=0){a=a.substring(c+1)}tokens=a.split("&");for(i=0;i<tokens.length;++i){param_tokens=tokens[i].split("=");if(param_tokens.length==2){b[param_tokens[0]]=param_tokens[1]}}return b};openark_schart.prototype.read_google_url=function(b){params=this.parse_url(b);this.title_height=0;if(params.chtt){this.chart_title=params.chtt;this.title_height=20}if(params.chco){var h=params.chco.split(",");this.plot_colors=[];for(i=0;i<h.length;++i){this.plot_colors.push("#"+h[i])}}this.recalc();if(params.chxl){var d=params.chxl;var j=[];for(i=0,pos=0;pos>=0;++i){pos=d.indexOf(""+i+":|");if(pos<0){j.push(d);break}var c=d.substring(0,pos);if(c.length){if(c.substring(c.length-1)=="|"){c=c.substring(0,c.length-1)}j.push(c)}d=d.substring(pos+3)}this.x_axis_labels=j[0].split("|");this.x_axis_label_positions=[];for(i=0;i<this.x_axis_labels.length;++i){var g=Math.floor(this.chart_origin_x+i*this.chart_width/(this.x_axis_labels.length-1));this.x_axis_label_positions.push(g)}this.y_axis_labels=j[1].split("|");this.y_axis_label_positions=[];for(i=0;i<this.y_axis_labels.length;++i){var f=Math.floor(this.chart_origin_y-i*this.chart_height/(this.y_axis_labels.length-1));this.y_axis_label_positions.push(f)}}if(params.chd){var n=params.chd;var e=n.substring(0,2);if(e=="t:"){this.dot_x_positions=[];this.dot_y_positions=[];this.dot_values=[];this.dot_colors=[];n=n.substring(2);var h=n.split("|");var a=h[0].split(",");var k=h[1].split(",");var m=null;if(h.length>2){m=h[2].split(",")}else{m=new Array(a.length)}for(i=0;i<m.length;++i){var g=Math.floor(this.chart_origin_x+parseInt(a[i])*this.chart_width/100);this.dot_x_positions.push(g);var f=Math.floor(this.chart_origin_y-parseInt(k[i])*this.chart_height/100);this.dot_y_positions.push(f);var l=null;if(m[i]&&(m[i]!="_")){l=Math.floor(m[i]*openark_schart.max_dot_size/100)}this.dot_values.push(l);this.dot_colors.push(this.gradient(this.plot_colors[0],this.plot_colors[1],m[i]))}}}this.redraw()};openark_schart.prototype.redraw=function(){this.create_graphics();this.draw()};openark_schart.prototype.draw=function(){if(this.chart_title){this.draw_text({text:this.chart_title,left:0,top:0,width:this.canvas_width,height:this.title_height,text_align:"center",font_size:openark_schart.title_font_size})}for(i=0;i<this.dot_values.length;++i){if(this.dot_values[i]!=null){this.draw_circle(this.dot_x_positions[i],this.dot_y_positions[i],this.dot_values[i],this.dot_colors[i])}}this.set_color(openark_schart.axis_color);for(i=0;i<this.x_axis_label_positions.length;++i){if(this.x_axis_labels[i]){this.draw_text({text:""+this.x_axis_labels[i],left:this.x_axis_label_positions[i]-25,top:this.chart_origin_y+openark_schart.max_dot_size+5,width:50,height:openark_schart.axis_font_size,text_align:"center"})}}for(i=0;i<this.y_axis_label_positions.length;++i){if(this.y_axis_labels[i]){this.draw_text({text:""+this.y_axis_labels[i],left:0,top:this.y_axis_label_positions[i]-openark_schart.axis_font_size+Math.floor(openark_schart.axis_font_size/3),width:this.y_axis_values_width-openark_schart.max_dot_size-5,height:openark_schart.axis_font_size,text_align:"right"})}}};openark_schart.prototype.set_color=function(a){this.current_color=a;if(!this.isIE){this.ctx.strokeStyle=a}};openark_schart.prototype.draw_circle=function(b,e,a,c){if(this.isIE){var d=document.createElement("v:oval");d.style.position="absolute";d.style.left=b-a;d.style.top=e-a;d.style.width=a*2;d.style.height=a*2;d.setAttribute("stroked","false");d.setAttribute("filled","true");d.setAttribute("fillcolor",""+c);this.container.appendChild(d)}else{this.ctx.fillStyle=this.dot_colors[i];this.ctx.beginPath();this.ctx.arc(b,e,a,0,Math.PI*2,true);this.ctx.closePath();this.ctx.fill()}};openark_schart.prototype.draw_text=function(b){var a=document.createElement("div");a.style.position="absolute";a.style.left=""+b.left+"px";a.style.top=""+b.top+"px";a.style.width=""+b.width+"px";a.style.height=""+b.height+"px";a.style.textAlign=""+b.text_align;a.style.verticalAlign="top";if(b.font_size){a.style.fontSize=""+b.font_size+"pt"}a.innerHTML=b.text;this.container.appendChild(a)};
SCHART

=head1 ATTRIBUTES

=cut


=head1 SUBROUTINES/METHODS

=head2 parse_options

parse the options, if there is a 'help' or 'man', print help info and exit

=cut

sub parse_options {
    

    local @ARGV ;
    push @ARGV, @_;

    Getopt::Long::Configure("bundling");
    Getopt::Long::GetOptions
        (
         'h|help' => \&show_help,
         'u|user=s' => \$options{user},
         'H|host=s' => \$options{host},
         'p|password=s' => \$options{password},
         'ask-pass' => \$options{prompt_password},
         'P|port=i' => \$options{port},
         'S|socket=s' => \$options{socket},
         'monitored-host=s' => \$options{monitored_host},
         'monitored-port=s' => \$options{monitored_host},
         'monitored-socket=s' => \$options{monitored_socket},
         'monitored-user=s' => \$options{monitored_user},
         'monitored-password=s' => \$options{monitored_password},
         'defaults-file=s' => \$options{defaults_file},
         'd|database=s' => \$options{database},
         'skip-aggregation' => \$options{skip_aggregation},
         'rebuild-aggregation' => \$options{rebuild_aggregation},
         'purge-days=i' => \$options{purge_days},
         'disable-bin-log' => \$options{disable_bin_log},
         'skip-disable-bin-log' => sub {$options{disable_bin_log} = 0},
         'skip-check-replication' => \$options{skip_check_replication},
         'o|force-os-monitoring' => \$options{force_os_monitoring},
         'skip-alerts' => \$options{skip_alerts},
         'skip-emails' => \$options{skip_emails},
         'force-emails' => \$options{force_emails},
         'skip-custom' => \$options{skip_custom},
         'skip-defaults-file' => \$options{skip_defaults_file},
         'chart-width=i' => sub {shift; my $w = shift; $options{chart_width} = $w > 150 ? $w : 150},
         'chart-height=i' => sub {shift; my $h = shift; $options{chart_height} = $h > 100 ? $h : 100},
         'chart-service-url=s' => \$options{chart_service_url},
         'smtp-host=s' => \$options{smtp_host},
         'smtp-from=s' => \$options{smtp_from},
         'smtp-to=s' => \$options{smtp_to},
         'http-port=i' => \$options{http_port},
         'debug' => \$options{debug},
         'v|verbose' => \$options{verbose},
         'version' => \$options{version},

        );

    # TODO: parse configure file

    $args = \@ARGV;

    verbose("mysqlmonitor version $VERSION. Copyright (c) 2012-2013 by Chylli", $options{version});
    die "No database specified. Specify with -d or --database\n" unless $options{database};
    die "purge-days must be at least 1\n" if $options{purge_days} < 1;
    verbose("database is $options{database}");

    for my $arg (@{$args}) {
        if ($arg eq 'deploy') {
            verbose("Deploy requested. Will deploy");
            $action{should_deploy} = 1;
        }
        elsif ($arg eq 'email_brief_report') {
            $action{should_email_brief_report} = 1;
        }
        elsif ($arg eq 'http') {
            $action{should_serve_http} = 1;
        }
        else {
            die "Unkown command: $arg\n";
        }
    }

    $database_name = $options{database};
    return %options
}


=head2 show_help

print help information.

=cut

sub show_help {
    
    print $help_msg, "\n";
    exit 0;
}

sub stub {
    
    my $option = shift;
    print "option $option not implemented yet\n";
    exit 0;
}

=head2 verbose

print messages when program is in verbose mode.

=cut

sub verbose {
    
    my ($message, $force_verbose) = @_;
    print "-- $message\n" if $options{verbose} || $force_verbose;
}

=head2 print_error

=cut

sub print_error {
    
    my $message = shift;
    print STDERR "-- ERROR: $message\n";
}



=head2 open_connections

open monitored and wrote dbi

return dbh of monitored and wrote db.

=cut

sub open_connections{
    
    my $password = $options{password};
    if ($options{prompt_password}) {
        print "Password:";
        ReadMode 'noecho';
        $password = ReadLine 0;
        chomp $password;
        ReadMode 'restore';
        $options{password} = $password;
    }

    my $dsn = "DBI:mysql:database=$options{database};host=$options{host};port=$options{port};mysql_socket=$options{socket}";
    # raise error, to catch exception
    my $write_connection = DBI->connect($dsn, $options{user}, $password,{RaiseError => 1, PrintError => 0 });

    if (not $options{monitored_host}){
        $monitored_conn = $write_conn = $write_connection;
        return ($write_connection, $write_connection);
    }

    verbose("monitored host is: $options{monitored_host}");

    if (! $options{monitored_user}) {
        $options{monitored_user} = $options{user};
        $options{monitored_password} = $options{password};
        verbose("monitored host credentials undefined; using write host credentials")
    }
    if (not $options{monitored_socket}){
        $options{monitored_socket} = $options{socket}
    }
    
    # Need to open a read connection
    $dsn = "DBI:mysql:database=test;host=$options{monitored_host};port=$options{monitored_port};mysql_socket=$options{monitored_socket}";
    my $monitored_connection = DBI->connect($dsn, $options{monitored_user}, $options{monitored_password},{RaiseError => 1, PrintError => 0});

    $monitored_conn = $monitored_connection;
    $write_conn = $write_connection;
    return ($monitored_connection, $write_connection);

}

=head2 init_connections

init connections

=cut

sub init_connections{
    
    my $sql = 'SET @@group_concat_max_len = GREATEST(@@group_concat_max_len, @@max_allowed_packet)';
    act_query($sql, $monitored_conn);
    act_query($sql, $write_conn);

}

=head2 act_query

do query.

=cut

sub act_query{
    
    my ($query, $connection) = @_;

    $connection = $write_conn if not $connection;
    return $connection->do($query);
}

=head2 get_monitored_host_mysql_version

=cut

sub get_monitored_host_mysql_version{
    
    my $version = get_row("select version() as version")->{'version'};
    return $version;
}

=head2 get_row

=cut

sub get_row{
    my ($query, $connection) = @_;
    $connection ||= $monitored_conn;
    my $row = $connection->selectrow_hashref($query);
    return $row;
}

=head2 get_rows

=cut


sub get_rows{
    my ($query, $connection) = @_;
    $connection ||= $monitored_conn;
    my $raise_error = $connection->{RaiseError};
    my @rows = @{ $connection->selectall_arrayref($query, { Slice => {} }) };
    return @rows;
}


=head2 create_table

=cut

sub recreate_table {
    
    my ($table, $col_info, $insert_sql) = @_;

    my $database = $options{database};
    my $query = "DROP TABLE IF EXISTS $database.$table";

    eval {
        act_query($query);
        1;
    } or die "Cannot execute query: $query\n";

    $query = "CREATE TABLE $database.$table ( $col_info )";

    eval {
        act_query($query);
        verbose("$table table created");
        1;
    } or die "Cannot create table $database.$table\n";
    
    $query = "INSERT IGNORE INTO $database.$table $insert_sql";

    if ($query){
        act_query($query);
    }
}

=head2 create_numbers_table

=cut

sub create_numbers_table {
    



    my $col_info = <<EOF;
            n SMALLINT UNSIGNED NOT NULL,
            PRIMARY KEY (n)
EOF

    my $numbers_values = join ",", map {"($_)"} (0..4095);
    my $insert_sql = <<EOF;
        VALUES $numbers_values
EOF

    recreate_table("numbers", $col_info, $insert_sql);

}

=head2 create_metadata_table

create metadata table

=cut


sub create_metadata_table{
    

    
    my $col_info = <<EOF;
            version decimal(5,2) UNSIGNED NOT NULL,
            last_deploy TIMESTAMP NOT NULL,
            last_deploy_successful TINYINT UNSIGNED NOT NULL DEFAULT 0,
            mysql_version VARCHAR(255) CHARSET ascii NOT NULL,
            database_name VARCHAR(255) CHARSET utf8 NOT NULL,
            custom_queries VARCHAR(4096) CHARSET ascii NOT NULL
EOF

    my $mysql_version = get_monitored_host_mysql_version();
    my $database = $options{database};
    my $insert_sql = <<EOF;
            (version, last_deploy_successful, mysql_version, database_name, custom_queries)
        VALUES
            ('$VERSION', 0, '$mysql_version', '$database','')
EOF

    recreate_table("metadata", $col_info, $insert_sql);

}


=head2 create_charts_api_table

=cut

sub create_charts_api_table {
    

    my $col_info = <<EOF;
            chart_width SMALLINT UNSIGNED NOT NULL,
            chart_height SMALLINT UNSIGNED NOT NULL,
            simple_encoding CHAR(62) CHARSET ascii COLLATE ascii_bin,
            service_url VARCHAR(128) CHARSET ascii COLLATE ascii_bin
EOF

    my $chart_height = $options{chart_height};
    my $chart_width = $options{chart_width};
    my $chart_service_url = $options{chart_service_url};

    my $insert_sql = <<EOF;
            (chart_width, chart_height, simple_encoding, service_url)
        VALUES
            ('$chart_width', '$chart_height', 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789', '$chart_service_url')
EOF

    recreate_table("charts_api", $col_info, $insert_sql);


}

=head2 create_html_components_table


=cut

sub create_html_components_table {
    

    my $col_info = <<EOF;
            openark_lchart TEXT CHARSET ascii COLLATE ascii_bin,
            openark_schart TEXT CHARSET ascii COLLATE ascii_bin,
            common_css TEXT CHARSET ascii COLLATE ascii_bin
EOF

    my $common_css = <<'EOF';
            div.http_html_embed {
                background: #f6f0f0;
                margin: 10px 10px 0px 10px;
                padding: 4px 0px 4px 0px;
            }
            body {
                background:#e0e0e0 none repeat scroll 0%;
                color:#505050;
                font-family:Verdana,Arial,Helvetica,sans-serif;
                font-size:9pt;
                line-height:1.5;
            }
            .corner { position: absolute; width: 8px; height: 8px; background: url('data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAACQkWg2AAAAAXNSR0IArs4c6QAAAAlwSFlzAAALEwAACxMBAJqcGAAAAAd0SU1FB9oGGREdC6h6BI8AAAAZdEVYdENvbW1lbnQAQ3JlYXRlZCB3aXRoIEdJTVBXgQ4XAAAA2UlEQVQoz5WSS2rEMBBESx/apqWV7384n0CrlhCNPlloMgmZiePUphG8B4Uoc54nPsPMIQTvvbUWwBijtZZzLqU8Gb8OEcUYmdk5h28hom3b9n0XEVV9CER0HAcRGWPwEudcjJGIUkqqagGs91t6xRizKgDwzMzMF/TTYeZaqw0h/Oj9W5xzIQTrvcftrA+094X/0Q9njHGfHmPY1tp9obVmc8699zt07z3nbEsppZQ55zU951ykBbB2cuHMOVVVRABYAKqaUhKRt9167yKyhvS11uXUWv+c9wcqkoXk2CZntQAAAABJRU5ErkJggg%3D%3D') no-repeat; font-size: 0; }
            .tl { top: 0; left: 0; background-position: 0 0; }
            .tr { top: 0; right: 0; background-position: -8px 0; }
            .bl { bottom: 0; left: 0; background-position: 0 -8px; }
            .br { bottom: 0; right: 0; background-position: -8px -8px; }
            .clear {
                clear: both;
            }
            .nobr {
                white-space: nowrap;
            }
            strong {
                font-weight: bold;
            }
            strong.db {
                font-weight: bold;
                font-size: 24px;
                color:#f26522;
            }
            a {
                color:#f26522;
                text-decoration:none;
            }
            hr {
                border: 0;
                height: 1px;
                background: #e0e0e0;
            }
            h1 {
                margin: 0 0 10 0;
                font-size: 16px;
            }
            h2 {
                font-size:13.5pt;
                font-weight:normal;
            }
            h2 a {
                font-weight:normal;
                font-size: 60%;
            }
            h3 {
                font-size:10.5pt;
                font-weight:normal;
            }
            h3 a {
                font-weight:normal;
                font-size: 80%;
            }
            div.header_content {
                padding: 10px;
            }
            div.custom_chart {
                margin-bottom: 40px;
            }
EOF

    $openark_lchart =~ tr/'/"/;
    $openark_schart =~ tr/'/"/;
    $common_css =~ tr/'/"/;

    my $insert_sql = <<EOF;
            (openark_lchart, openark_schart, common_css)
        VALUES
            ('$openark_lchart', '$openark_schart', '$common_css')
EOF
        recreate_table("html_components", $col_info, $insert_sql);


}

=head2 create_custom_query_table

=cut

sub create_custom_query_table{
    my $query = <<EOF;
      CREATE TABLE IF NOT EXISTS $options{database}.custom_query (
          custom_query_id INT UNSIGNED,
          enabled BOOL NOT NULL DEFAULT 1,
          query_eval VARCHAR(4095) CHARSET utf8 COLLATE utf8_bin NOT NULL,
          description VARCHAR(255) CHARSET utf8 COLLATE utf8_bin DEFAULT NULL,
          chart_type ENUM('value', 'value_psec', 'time', 'none') NOT NULL DEFAULT 'value',
          chart_order TINYINT(4) NOT NULL DEFAULT '0',
          PRIMARY KEY (custom_query_id)
        )
EOF

    eval {
        act_query($query);
        verbose("custom_query table created");
        1;
    } or die "Cannot create table $options{database}.custom_query\n";

    $query = <<EOF;
        UPDATE $options{database}.metadata 
        SET custom_queries = 
            (SELECT 
                IFNULL(
                  GROUP_CONCAT(
                    CONCAT(custom_query_id, ':', chart_type) 
                    ORDER BY chart_order, custom_query_id SEPARATOR ','
                  )
                  , '') 
            FROM $options{database}.custom_query
            ) 

EOF

    act_query($query);


}

=head2 create_custom_query_view

=cut

sub create_custom_query_view{
    my $query = <<EOF;
        CREATE
        OR REPLACE
        ALGORITHM = TEMPTABLE
        DEFINER = CURRENT_USER
        SQL SECURITY INVOKER
        VIEW $options{database}.custom_query_view AS
          SELECT
            custom_query_id,
            enabled,
            query_eval,
            description,
            chart_type,
            chart_order,
            CASE chart_type
                WHEN 'value' THEN CONCAT('custom_', custom_query_id)
                WHEN 'value_psec' THEN CONCAT('custom_', custom_query_id, '_psec')
                WHEN 'time' THEN CONCAT('custom_', custom_query_id, '_time')
                WHEN 'none' THEN NULL
            END AS chart_name,
            CASE chart_type
                WHEN 'none' THEN 0
                ELSE 1
            END AS chart_enabled
          FROM
            $options{database}.custom_query
          ORDER BY 
            custom_query.chart_order, custom_query.custom_query_id
EOF

    act_query($query);
    verbose("custom_query_view created");

}

=head2 is_signed_column

=cut

sub is_signed_column{
    my $column_name = shift;
    my @known_signed_diff_status_variables = (
        "threads_cached",
        "threads_connected",
        "threads_running",
        "open_table_definitions",
        "open_tables",
        "slave_open_temp_tables",
        "qcache_free_blocks",
        "qcache_free_memory",
        "qcache_queries_in_cache",
        "qcache_total_blocks",
        "innodb_page_size",
        "innodb_buffer_pool_pages_total",
        "innodb_buffer_pool_pages_free",
        "innodb_buffer_pool_pages_data",
        "innodb_buffer_pool_pages_dirty",
        "innodb_buffer_pool_pages_misc",
        "key_blocks_unused",
        "key_cache_block_size",
        "master_status_position",
        "read_master_log_pos",
        "relay_log_pos",
        "exec_master_log_pos",
        "relay_log_space",
        "seconds_behind_master",
                                             );
    return any {$_ eq $column_name} @known_signed_diff_status_variables;
}

=head2 get_column_sign_indicator(column_name)

=cut

sub get_column_sign_indicator{
    my $column_name = shift;
    if (is_signed_column($column_name)){
        return "SIGNED";
    } else {
        return "UNSIGNED";
    }
}



=head2 get_custom_status_variables

=cut

sub get_custom_status_variables{
    my @custom_status_variables = map("custom_$_" , get_custom_query_ids());
    return @custom_status_variables;
}

=head2 get_custom_time_status_variables

=cut

sub get_custom_time_status_variables{
    my @custom_time_status_variables = map("custom_${_}_time", get_custom_query_ids());
    return @custom_time_status_variables;
}

=head2 get_custom_query_ids

    Returns ids of custom queries

=cut

sub get_custom_query_ids{
    if(not @custom_query_ids){
        my $query = "SELECT custom_query_id, chart_name FROM $database_name.custom_query_view";
        my @rows = get_rows($query, $write_conn);
        @custom_query_ids = map {$_->{custom_query_id}} @rows;
    }

    return @custom_query_ids;
}

=head2 get_additional_status_variables

=cut

sub get_additional_status_variables {
    my @additional_status_variables = 
      (
        "queries",
        "open_table_definitions",
        "opened_table_definitions",
        "innodb_buffer_pool_pages_free", 
        "innodb_buffer_pool_pages_total", 
        "innodb_buffer_pool_reads", 
        "innodb_buffer_pool_read_requests", 
        "innodb_buffer_pool_reads", 
        "innodb_buffer_pool_pages_flushed", 
        "innodb_buffer_pool_read_ahead",
        "innodb_buffer_pool_read_ahead_evicted",
        "innodb_os_log_written", 
        "innodb_row_lock_waits", 
        "innodb_row_lock_current_waits", 
        "innodb_row_lock_time", 
        "innodb_rows_read", 
        "innodb_rows_inserted", 
        "innodb_rows_updated", 
        "innodb_rows_deleted",
      );

    my @custom_status_variables = get_custom_status_variables();
    my @custom_time_status_variables = get_custom_time_status_variables();

    return (@additional_status_variables, @custom_status_variables, @custom_time_status_variables);

}

=head2 is_neglectable_variable

=cut

sub is_neglectable_variable{
    my $variable_name = shift;
    return 1 if ($variable_name =~ /^(ssl_|ndb_)/);
    return 1 if $variable_name eq 'last_query_cost';
    return 1 if $variable_name eq 'rpl_status';
    return 0;
}

=head2 normalize_variable_value(variable_name, variable_value)

=cut

sub normalize_variable_value{
    my ($variable_name, $variable_value) = @_;
    my $nvalue = $variable_value;
    my %mvalues;
    # First, handle special cases.
    # I'm fearful about name colisions, where values do not agree.
    if ($variable_name eq "concurrent_insert") {
        %mvalues = (
                      never => 0,
                      auto => 1,
                      always => 2,
                     );
       $nvalue =  $mvalues{$variable_value};
    }

    %mvalues = (
                  off => 0,
                  on => 1,
                  demand => 2,
                  no => 0,
                  yes => 1,
                 );
    if(exists($mvalues{$variable_value})){
        $nvalue = $mvalues{$variable_value};
    }
    if($variable_name eq 'delay_key_write' and $variable_value eq 'all'){
        $nvalue = 2;
    }
    return $nvalue ;

}

=head2 get_global_variables()

=cut

sub get_global_variables{
    my @global_variables = (
        "auto_increment_increment",
        "binlog_cache_size",
        "bulk_insert_buffer_size",
        "concurrent_insert",
        "connect_timeout",
        "delay_key_write",
        "delayed_insert_limit",
        "delayed_insert_timeout",
        "delayed_queue_size",
        "expire_logs_days",
        "foreign_key_checks",
        "group_concat_max_len",
        "innodb_additional_mem_pool_size",
        "innodb_autoextend_increment",
        "innodb_autoinc_lock_mode",
        "innodb_buffer_pool_size",
        "innodb_checksums",
        "innodb_commit_concurrency",
        "innodb_concurrency_tickets",
        "innodb_fast_shutdown",
        "innodb_file_io_threads",
        "innodb_file_per_table",
        "innodb_flush_log_at_trx_commit",
        "innodb_force_recovery",
        "innodb_lock_wait_timeout",
        "innodb_log_buffer_size",
        "innodb_log_file_size",
        "innodb_log_files_in_group",
        "innodb_max_dirty_pages_pct",
        "innodb_max_purge_lag",
        "innodb_mirrored_log_groups",
        "innodb_open_files",
        "innodb_rollback_on_timeout",
        "innodb_stats_on_metadata",
        "innodb_support_xa",
        "innodb_sync_spin_loops",
        "innodb_table_locks",
        "innodb_thread_concurrency",
        "innodb_thread_sleep_delay",
        "join_buffer_size",
        "key_buffer_size",
        "key_cache_age_threshold",
        "key_cache_block_size",
        "key_cache_division_limit",
        "large_files_support",
        "large_page_size",
        "large_pages",
        "locked_in_memory",
        "log_queries_not_using_indexes",
        "log_slow_queries",
        "long_query_time",
        "low_priority_updates",
        "max_allowed_packet",
        "max_binlog_cache_size",
        "max_binlog_size",
        "max_connect_errors",
        "max_connections",
        "max_delayed_threads",
        "max_error_count",
        "max_heap_table_size",
        "max_insert_delayed_threads",
        "max_join_size",
        "max_length_for_sort_data",
        "max_prepared_stmt_count",
        "max_relay_log_size",
        "max_seeks_for_key",
        "max_sort_length",
        "max_sp_recursion_depth",
        "max_tmp_tables",
        "max_user_connections",
        "max_write_lock_count",
        "min_examined_row_limit",
        "multi_range_count",
        "myisam_data_pointer_size",
        "myisam_max_sort_file_size",
        "myisam_repair_threads",
        "myisam_sort_buffer_size",
        "myisam_use_mmap",
        "net_buffer_length",
        "net_read_timeout",
        "net_retry_count",
        "net_write_timeout",
        "old_passwords",
        "open_files_limit",
        "optimizer_prune_level",
        "optimizer_search_depth",
        "port",
        "preload_buffer_size",
        "profiling",
        "profiling_history_size",
        "protocol_version",
        "pseudo_thread_id",
        "query_alloc_block_size",
        "query_cache_limit",
        "query_cache_min_res_unit",
        "query_cache_size",
        "query_cache_type",
        "query_cache_wlock_invalidate",
        "query_prealloc_size",
        "range_alloc_block_size",
        "read_buffer_size",
        "read_only",
        "read_rnd_buffer_size",
        "relay_log_space_limit",
        "rpl_recovery_rank",
        "server_id",
        "skip_external_locking",
        "skip_networking",
        "skip_show_database",
        "slave_compressed_protocol",
        "slave_net_timeout",
        "slave_transaction_retries",
        "slow_launch_time",
        "slow_query_log",
        "sort_buffer_size",
        "sql_auto_is_null",
        "sql_big_selects",
        "sql_big_tables",
        "sql_buffer_result",
        "sql_log_bin",
        "sql_log_off",
        "sql_log_update",
        "sql_low_priority_updates",
        "sql_max_join_size",
        "sql_notes",
        "sql_quote_show_create",
        "sql_safe_updates",
        "sql_select_limit",
        "sql_warnings",
        "sync_binlog",
        "sync_frm",
        "table_cache",
        "table_definition_cache",
        "table_lock_wait_timeout",
        "table_open_cache",
        "thread_cache_size",
        "thread_stack",
        "timed_mutexes",
        "timestamp",
        "tmp_table_size",
        "transaction_alloc_block_size",
        "transaction_prealloc_size",
        "unique_checks",
        "updatable_views_with_limit",
        "wait_timeout",
        "warning_count",
        );
    return @global_variables;
}

=head2 get_extra_variables

=cut

sub get_extra_variables{
    my @extra_variables = (
        "hostname",
        "datadir",
        "tmpdir",
        "version",
        "sql_mode",
        );
    return @extra_variables
}

=head2 get_monitored_host

=cut

sub get_monitored_host{
    my $monitored_host = $options{monitored_host};
    $monitored_host ||= $options{host};
    return $monitored_host
}

=head2 is_local_monitoring

=cut

sub is_local_monitoring{
    my $monitored_host = get_monitored_host();
    my @localhost = ('localhost', '127.0.0.1',hostname(),hostfqdn());
    return 1 if (any {$monitored_host eq $_} @localhost);
    return 0;

}

=head2 should_monitor_os

=cut

sub should_monitor_os{
    return 1 if ($options{force_os_monitoring} || is_local_monitoring());
    return 0;
}

=head2 get_page_io_activity

    From /proc/vmstat, read pages in/out, swap in/out (since kast reboot)

=cut

sub get_page_io_activity{

    #TODO

}

=head2 get_mountpoint_usage_percent(path):

    Find the mountpoint for the given path; return the integer number of disk used percent.

=cut

sub get_mountpoint_usage_percent{
    my $path = shift;
    my $mountpoint = abs_path($path);
    while(not is_mountpoint($mountpoint)){
        $mountpoint = dirname($mountpoint);
    }


    # The following calculation follows df.c (part of coreutils)
    # statvfs.f_blocks is total blocks
    # statvfs.f_bavail is available blocks
    # statvfs.f_bfree is blocks available to root
    my $ref = dfportable($mountpoint);

    my $used_blocks = $ref->{blocks} - $ref->{bfree};
    my $nonroot_total_blocks = $used_blocks + $ref->{bavail};

    use Data::Dumper;
    print Dumper($ref);

    print "used_blocks: $used_blocks, nonroot total_blocks: $nonroot_total_blocks\n";
    my $used_percent = int(100 * $used_blocks / $nonroot_total_blocks);
    if(100*$used_blocks % $nonroot_total_blocks != 0){
        $used_percent += 1;
    }

    return $used_percent;

}

=head2 fetch_status_variables

    Fill in the status_dict. We make point of filling in all variables, even those not existing,
    for having the dictionary hold the keys. Based on these keys, tables and views are created.
    So it is important that we have the dictionary include all possible keys.

=cut

sub fetch_status_variables{
    return %status_dict if %status_dict;

    # Make sure some status variables exist: these are required due to 5.0 - 5.1
    # or minor versions incompatibilities.
    for my $additional_status_variable (get_additional_status_variables()){
        $status_dict{$additional_status_variable} = undef;
    }

    my $query = 'show global status';
    my @rows = get_rows($query);
    for my $row (@rows) {
        my $variable_name = lc $row->{Variable_name};
        $variable_name =~ s/(^\s+)|(\s+$)//g;
        my $variable_value = lc $row->{Value};
        if (not is_neglectable_variable($variable_name)){
            $status_dict{$variable_name} = normalize_variable_value($variable_name,$variable_value);
        }
    }

    # Listing of interesting global variables:
    my @global_variables = get_global_variables();
    my @extra_variables = get_extra_variables();
    map {$status_dict{$_} = undef} @global_variables;
    $query = "SHOW GLOBAL VARIABLES";
    @rows = get_rows($query);
    for my $row (@rows) {
        my $variable_name = lc $row->{Variable_name};
        $variable_name =~ s/(^\s+)|(\s+$)//g;
        my $variable_value = lc $row->{Value};
        if (any {$_ eq $variable_name} @global_variables){
            $status_dict{$variable_name} = normalize_variable_value($variable_name,$variable_value);
        }
        elsif(any {$_ eq $variable_name} @extra_variables){
            $extra_dict{$variable_name} = $variable_value;
        }
    }
    
    $status_dict{metadata_version} = $VERSION;

    verbose("Global status & variables recorded");

    # Master & slave status
    $status_dict{"master_status_position"} = undef;
    $status_dict{"master_status_file_number"} = undef;
    my @slave_status_variables = (
        "Read_Master_Log_Pos",
        "Relay_Log_Pos",
        "Exec_Master_Log_Pos",
        "Relay_Log_Space",
        "Seconds_Behind_Master",
                                 );
    map {$status_dict{$_} = undef} @slave_status_variables;
    if(not $options{skip_check_replication}){
        eval {
            #local $SIG{__WARN__} = sub {};
            $query = "SHOW MASTER STATUS";
            my $master_status = get_row($query);
            if($master_status){
                $status_dict{"master_status_position"} = $master_status->{"Position"};
                my $log_file_name = $master_status->{"File"};
                my @splited_file_name = split /./, $log_file_name;
                my $log_file_number = $splited_file_name[-1];
                $status_dict{"master_status_file_number"} = $log_file_number;
            }
            $query = "SHOW SLAVE STATUS";
            my $slave_status = get_row($query);
            if ($slave_status){
                for my $variable_name  (@slave_status_variables){
                    $status_dict{lc $variable_name} = $slave_status->{$variable_name};
                }
            }
            verbose("Master and slave status recorded");
            1;
        } or   # An exception can be thrown if the user does not have enough privileges:
          print_error("Cannot show master & slave status. Skipping");

    }

    # OS (linux) load average
    $status_dict{"os_loadavg_millis"} = undef;
    # OS (linux) CPU
    $status_dict{"os_cpu_user"} = undef;
    $status_dict{"os_cpu_nice"} = undef;
    $status_dict{"os_cpu_system"} = undef;
    $status_dict{"os_cpu_idle"} = undef;
    $status_dict{"os_total_cpu_cores"} = undef;
    # OS Mem
    $status_dict{"os_mem_total_kb"} = undef;
    $status_dict{"os_mem_free_kb"} = undef;
    $status_dict{"os_mem_active_kb"} = undef;
    $status_dict{"os_swap_total_kb"} = undef;
    $status_dict{"os_swap_free_kb"} = undef;

    $status_dict{"os_root_mountpoint_usage_percent"} = undef;
    $status_dict{"os_datadir_mountpoint_usage_percent"} = undef;
    $status_dict{"os_tmpdir_mountpoint_usage_percent"} = undef;

    $status_dict{"os_page_ins"} = undef;
    $status_dict{"os_page_outs"} = undef;
    $status_dict{"os_swap_ins"} = undef;
    $status_dict{"os_swap_outs"} = undef;

    if(should_monitor_os()){
        eval {
            open(my $f, '/proc/stat');
            my @proc_stat_lines = <$f>;
            close ($f);
            my $first_line = $proc_stat_lines[0];
            my @tokens = split ' ', $first_line;
            @status_dict{qw(os_cpu_user os_cpu_nice os_cpu_system os_cpu_idle)} = @tokens[1..5];

            my @cpu_lines = grep (/^cpu\d/, @proc_stat_lines);
            $status_dict{os_total_cpu_cores} = scalar @cpu_lines;
            verbose('OS CPU info recorded');
        } or verbose("Cannot read /proc/stat. Skipping");


        eval {
            open(my $f,'/proc/loadavg');
            my $first_line = <$f>;
            close($f);
            my @tokens = split ' ', $first_line;
            my $loadavg_1_min = $tokens[0];
            $status_dict{os_loadavg_millis} = $loadavg_1_min * 1000;
            verbose("OS load average info recorded");
            } or verbose("Cannot read /proc/loadavg. Skipping");

        eval {
            open(my $f,'/proc/meminfo');
            my @lines = <$f>;
            close($f);

            for my $line (@lines) {
                my @tokens = split ' ', $line;
                my $param_name = lc $tokens[0];
                $param_name =~ s/://;
                my $param_value = $tokens[1];
                if ($param_name eq "memtotal"){
                    $status_dict{"os_mem_total_kb"} = $param_value;
                }
                elsif ($param_name eq "memfree"){
                    $status_dict{"os_mem_free_kb"} = $param_value;
                }
                elsif ($param_name eq "active"){
                    $status_dict{"os_mem_active_kb"} = $param_value;
                }
                elsif ($param_name eq "swaptotal"){
                    $status_dict{"os_swap_total_kb"} = $param_value;
                }
                elsif ($param_name eq "swapfree"){
                    $status_dict{"os_swap_free_kb"} = $param_value;
                }
            }
            verbose("OS mem info recorded")

        } or verbose('Cannot read /proc/meminfo. Skipping');

        # Filesystems:
        eval {
            $status_dict{"os_root_mountpoint_usage_percent"} = get_mountpoint_usage_percent("/");
            $status_dict{"os_datadir_mountpoint_usage_percent"} = get_mountpoint_usage_percent($extra_dict{"datadir"});
            $status_dict{"os_tmpdir_mountpoint_usage_percent"} = get_mountpoint_usage_percent(extra_dict{"tmpdir"});
            verbose("OS mountpoints info recorded");
        } or verbose("Cannot read mountpoints info. Skipping");

        eval {
            my ($pgpgin, $pgpgout, $pswpin, $pswpout) = get_page_io_activity();

        } or  verbose("Cannot read page io activity. Skipping")


        #TODO

    }


          #TODO

    return %status_dict;

}

=head2 get_status_variables_columns

    Return all columns participating in the status variables table. Most of these are STATUS variables.
    Others are parameters. Others yet represent slave or master status etc.

=cut

sub get_status_variables_columns{
    my %status = fetch_status_variables();
    my @status_name =  sort {$a cmp $b} (keys %status);
    return @status_name;
}



=head2 create_status_variables_table

=cut

sub create_status_variables_table{
    my $columns_listing = '';
    for my $column_name (get_status_variables_columns()) {
        my $column_sign_indicator = get_column_sign_indicator($column_name);
        $columns_listing .= "$column_name BIGINT $column_sign_indicator\n";
    }

    my $query = <<EOF;
        CREATE TABLE $options{database}.$table_name (
            id INT AUTO_INCREMENT PRIMARY KEY,
            ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            $columns_listing,
            UNIQUE KEY ts (ts)
       )
EOF

    my $table_created = 0;
    eval {
        act_query($query);
        $table_created = 1;
        verbose("$table_name table created");
        1;
    } or verbose("table_name table exists");

    return $table_created;

}

=head2 upgrade_status_variables_table

=cut

sub upgrade_status_variables_table{
    # TODO

}

=head2 deploy_schema

deploy the schema

=cut

sub deploy_schema{
    
    create_metadata_table();
    create_numbers_table();
    create_charts_api_table();
    create_html_components_table();
    create_custom_query_table();
    create_custom_query_view();
    fetch_status_variables();
    #if(not create_status_variables_table()){
    #    upgrade_status_variables_table;
    #}

}


=head2 is_same_deploy

tell if the deployed schema is the same with the existed schema

=cut

sub is_same_deploy{
    
    # TODO

    return 0;

}

=head2 run

The program entrance.

=cut

sub run {
    
    parse_options(@_);





    # Open connections. From this point and on, database access is possible
    my ($monitored_conn, $write_conn) = open_connections();
    init_connections();

    my $should_deploy = $action{should_deploy};
    if (not $should_deploy && not is_same_deploy()){
        verbose("Non matching deployed revision. Will auto-deploy");
        $should_deploy = 1;
    }
    if ($should_deploy){
        deploy_schema();
        # TODO
    }


    # TODO
    # do the concreate things
}

=head1 AUTHOR

chylli, C<< <chylli.email at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-mysqlmonitor at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=mysqlmonitor>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc MySQL::Monitor


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=mysqlmonitor>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/mysqlmonitor>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/mysqlmonitor>

=item * Search CPAN

L<http://search.cpan.org/dist/mysqlmonitor/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2012 chylli.

This program is distributed under the (Simplified) BSD License:
L<http://www.opensource.org/licenses/BSD-2-Clause>

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions
are met:

* Redistributions of source code must retain the above copyright
notice, this list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright
notice, this list of conditions and the following disclaimer in the
documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


=cut

1; # End of MySQL::Monitor
