//! 任务列表与详情查询。

mod detail;
mod list;
mod page;

#[allow(unused_imports)]
pub(crate) use detail::{
    __path_get_job, __path_get_job_file, __path_get_job_task_detail_compat, get_job, get_job_file,
    get_job_task_detail_compat,
};
#[allow(unused_imports)]
pub(crate) use list::{__path_list_jobs, list_jobs};
#[allow(unused_imports)]
pub(crate) use page::{__path_list_jobs_page, list_jobs_page};
