using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Usr.Service.Models;
using Usr.Service.Services;

namespace Usr.Service.Controllers
{
    [Route("api/v1/[controller]")]
    [ApiController]
    public class UsrController : ControllerBase
    {
        private Htpasswd _htpasswdService;
        private OpenShiftClient _oc;

        public UsrController(Htpasswd htpasswdService, OpenShiftClient oc)
        {
            _oc = oc;
            _htpasswdService = htpasswdService;
        }

        [HttpGet("init")]
        public async Task<IActionResult> Init()
        {
            // Initialization Logic:


            return Ok();
        }

        [HttpPost]
        public async Task<IActionResult> Create(UsrModel model)
        {
            // Create User Logic:
            List<string> outputResults = [];

            // 1.) Create User in HTPasswd:
            outputResults.Add(await _htpasswdService.UpsertUser(model.Username, model.Password));

            // 2.) Update OCP HTPasswd ConfigMap:


            // 3.) Apply User Creation YAML Templates:


            return Ok();
        }
    }
}
