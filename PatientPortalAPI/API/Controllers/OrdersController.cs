using Microsoft.AspNetCore.Mvc;
using PatientPortalAPI.Core.Application.Interfaces;
using PatientPortalAPI.Core.Domain;

namespace PatientPortalAPI.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Produces("application/json")]
public class OrdersController(IOrderRepository orderRepository) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> GetAll() => Ok(await orderRepository.GetAllAsync());

    [HttpGet("{id:guid}")]
    public async Task<IActionResult> GetById(Guid id)
    {
        var order = await orderRepository.GetByIdAsync(id);
        return order == null ? NotFound() : Ok(order);
    }

    [HttpGet("patient/{patientId:guid}")]
    public async Task<IActionResult> GetByPatient(Guid patientId)
    {
        return Ok(await orderRepository.GetByPatientIdAsync(patientId));
    }

    [HttpPost]
    public async Task<IActionResult> Create([FromBody] Order order)
    {
        var id = await orderRepository.AddAsync(order);
        order.OrderID = id;
        return CreatedAtAction(nameof(GetById), new { id = order.OrderID }, order);
    }

    [HttpPut("{id:guid}")]
    public async Task<IActionResult> Update(Guid id, [FromBody] Order order)
    {
        if (id != order.OrderID) return BadRequest();
        return await orderRepository.UpdateAsync(order) ? NoContent() : NotFound();
    }

    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> Delete(Guid id) => await orderRepository.DeleteAsync(id) ? NoContent() : NotFound();
}
