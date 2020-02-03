using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;

namespace Project
{
    public partial class Main : System.Web.UI.Page
    {
        protected void Page_Load(object sender, EventArgs e)
        {

        }

        protected void Button1_Click(object sender, EventArgs e)
        {
            String d = "<ol class='list-group'>";
            
            int studentId = Convert.ToInt32(txtstudentId.Text);


            dsTableAdapters.spGetCourseByStudentIdTableAdapter tbl =
                new dsTableAdapters.spGetCourseByStudentIdTableAdapter();
            foreach (ds.spGetCourseByStudentIdRow row in tbl.GetData(studentId))
            {
                d += "<li class='list-group-item'>" +
                     "<img src=https://robohash.org/" +
                            row.name.Replace(" ", "") + ".png width='50' />" +
                            row.name + " - " + row.ProfessorName + ", " +
                            row.location + " " + row.courseId +
                     "</li>";
            }

            ulListCB.Text = d + "</ol>";
        }
    }
}