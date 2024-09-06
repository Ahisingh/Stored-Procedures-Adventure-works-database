USE AdventureWorks2022
GO
CREATE PROCEDURE InsertOrderDetails1
    @OrderID INT,
    @ProductID INT,
    @UnitPrice MONEY = NULL,
    @Quantity INT,
    @Discount FLOAT = 0
AS
BEGIN
    DECLARE @StockQuantity INT;
    DECLARE @ReorderLevel INT;
    DECLARE @ProductUnitPrice MONEY;

    -- Get the product's UnitPrice and ReorderLevel
    SELECT @ProductUnitPrice = ListPrice, @ReorderLevel = SafetyStockLevel
    FROM Production.Product
    WHERE ProductID = @ProductID;

    -- If UnitPrice is not provided, use the product's UnitPrice
    SET @UnitPrice = ISNULL(@UnitPrice, @ProductUnitPrice);

    -- Get the stock quantity from ProductInventory
    SELECT @StockQuantity = SUM(Quantity)
    FROM Production.ProductInventory
    WHERE ProductID = @ProductID;

    -- Check if there is enough stock
    IF @StockQuantity < @Quantity
    BEGIN
        PRINT 'Not enough stock. Aborting the operation.';
        RETURN;
    END

    -- Insert the order detail
    INSERT INTO Sales.SalesOrderDetail (SalesOrderID, ProductID, UnitPrice, OrderQty, UnitPriceDiscount)
    VALUES (@OrderID, @ProductID, @UnitPrice, @Quantity, @Discount);

    -- Check if the order was inserted
    IF @@ROWCOUNT = 0
    BEGIN
        PRINT 'Failed to place the order. Please try again.';
        RETURN;
    END

    -- Adjust the stock quantity
    UPDATE Production.ProductInventory
    SET Quantity = Quantity - @Quantity
    WHERE ProductID = @ProductID;

    -- Check if the stock quantity is below reorder level
    IF @StockQuantity - @Quantity < @ReorderLevel
    BEGIN
        PRINT 'Warning: The quantity in stock of this product has dropped below its Reorder Level.';
    END
END;
GO

CREATE PROCEDURE UpdateOrderDetails
    @OrderID INT,
    @ProductID INT,
    @UnitPrice MONEY = NULL,
    @Quantity INT = NULL,
    @Discount FLOAT = NULL
AS
BEGIN
    DECLARE @OldQuantity INT;
    DECLARE @NewQuantity INT;
    DECLARE @OldUnitPrice MONEY;
    DECLARE @OldDiscount FLOAT;
    DECLARE @StockQuantity INT;

    -- Get current order details
    SELECT @OldUnitPrice = UnitPrice, @OldQuantity = OrderQty, @OldDiscount = UnitPriceDiscount
    FROM Sales.SalesOrderDetail
    WHERE SalesOrderID = @OrderID AND ProductID = @ProductID;

    -- Set new values to old ones if not provided
    SET @UnitPrice = ISNULL(@UnitPrice, @OldUnitPrice);
    SET @Quantity = ISNULL(@Quantity, @OldQuantity);
    SET @Discount = ISNULL(@Discount, @OldDiscount);

    -- Get current stock quantity
    SELECT @StockQuantity = Quantity
    FROM Production.ProductInventory
    WHERE ProductID = @ProductID;

    -- Adjust stock quantity
    SET @NewQuantity = @Quantity - @OldQuantity;
    IF @StockQuantity < @NewQuantity
    BEGIN
        PRINT 'Not enough stock. Aborting the operation.';
        RETURN;
    END

    -- Update the order detail
    UPDATE Sales.SalesOrderDetail
    SET UnitPrice = @UnitPrice, OrderQty = @Quantity, UnitPriceDiscount = @Discount
    WHERE SalesOrderID = @OrderID AND ProductID = @ProductID;

    -- Adjust the stock quantity
    UPDATE Production.ProductInventory
    SET Quantity = Quantity - @NewQuantity
    WHERE ProductID = @ProductID;
END;
GO

CREATE PROCEDURE GetOrderDetails
    @OrderID INT
AS
BEGIN
    IF NOT EXISTS (SELECT 1 FROM Sales.SalesOrderDetail WHERE SalesOrderID = @OrderID)
    BEGIN
        PRINT 'The OrderID ' + CAST(@OrderID AS VARCHAR) + ' does not exist';
        RETURN 1;
    END

    SELECT * FROM Sales.SalesOrderDetail
    WHERE SalesOrderID = @OrderID;
END;
GO

CREATE PROCEDURE DeleteOrderDetails
    @OrderID INT,
    @ProductID INT
AS
BEGIN
    IF NOT EXISTS (SELECT 1 FROM Sales.SalesOrderDetail WHERE SalesOrderID = @OrderID AND ProductID = @ProductID)
    BEGIN
        PRINT 'Invalid parameters. The OrderID or ProductID does not exist.';
        RETURN -1;
    END

    DELETE FROM Sales.SalesOrderDetail
    WHERE SalesOrderID = @OrderID AND ProductID = @ProductID;

    IF @@ROWCOUNT = 0
    BEGIN
        PRINT 'Failed to delete the order detail. Please try again.';
        RETURN -1;
    END

    PRINT 'Order detail deleted successfully.';
END;
GO

CREATE PROCEDURE DeleteOrderDetails1
    @OrderID INT,
    @ProductID INT
AS
BEGIN
    IF NOT EXISTS (SELECT 1 FROM Sales.SalesOrderDetail WHERE SalesOrderID = @OrderID AND ProductID = @ProductID)
    BEGIN
        PRINT 'Invalid parameters. The OrderID or ProductID does not exist.';
        RETURN -1;
    END

    DELETE FROM Sales.SalesOrderDetail
    WHERE SalesOrderID = @OrderID AND ProductID = @ProductID;

    IF @@ROWCOUNT = 0
    BEGIN
        PRINT 'Failed to delete the order detail. Please try again.';
        RETURN -1;
    END

    PRINT 'Order detail deleted successfully.';
END;
GO


CREATE FUNCTION dbo.FormatDateMMDDYYYY (@inputDate DATETIME)
RETURNS VARCHAR(10)
AS
BEGIN
    RETURN CONVERT(VARCHAR(10), @inputDate, 101);
END;
GO

CREATE FUNCTION dbo.FormatDateYYYYMMDD (@inputDate DATETIME)
RETURNS VARCHAR(8)
AS
BEGIN
    RETURN CONVERT(VARCHAR(8), @inputDate, 112);
END;
GO

CREATE FUNCTION dbo.Format_DateYYYYMMDD (@inputDate DATETIME)
RETURNS VARCHAR(8)
AS
BEGIN
    RETURN CONVERT(VARCHAR(8), @inputDate, 112);
END;
GO

/*view*/

CREATE VIEW vwCustomerOrders AS
SELECT 
    c.AccountNumber AS CustomerName,
    o.SalesOrderID AS OrderID,
    o.OrderDate,
    od.ProductID,
    p.Name AS ProductName,
    od.OrderQty AS Quantity,
    od.UnitPrice,
    od.OrderQty * od.UnitPrice AS TotalPrice
FROM 
    Sales.Customer AS c
    INNER JOIN Sales.SalesOrderHeader AS o ON c.CustomerID = o.CustomerID
    INNER JOIN Sales.SalesOrderDetail AS od ON o.SalesOrderID = od.SalesOrderID
    INNER JOIN Production.Product AS p ON od.ProductID = p.ProductID;
GO

CREATE VIEW vwCustomerOrdersYesterday AS
SELECT 
    c.AccountNumber AS CustomerName,
    o.SalesOrderID AS OrderID,
    o.OrderDate,
    od.ProductID,
    p.Name AS ProductName,
    od.OrderQty AS Quantity,
    od.UnitPrice,
    od.OrderQty * od.UnitPrice AS TotalPrice
FROM 
    Sales.Customer AS c
    INNER JOIN Sales.SalesOrderHeader AS o ON c.CustomerID = o.CustomerID
    INNER JOIN Sales.SalesOrderDetail AS od ON o.SalesOrderID = od.SalesOrderID
    INNER JOIN Production.Product AS p ON od.ProductID = p.ProductID
WHERE 
    o.OrderDate = CAST(GETDATE() - 1 AS DATE);
GO
 

CREATE VIEW MyProducts AS
SELECT 
    p.ProductID,
    p.Name AS ProductName,
    p.Size,
    p.Weight,
    p.ListPrice AS UnitPrice,
    s.Name AS SupplierName,
    c.Name AS CategoryName
FROM 
    Production.Product AS p
    INNER JOIN Purchasing.ProductVendor AS pv ON p.ProductID = pv.ProductID
    INNER JOIN Purchasing.Vendor AS s ON pv.BusinessEntityID = s.BusinessEntityID
    INNER JOIN Production.ProductSubcategory AS sc ON p.ProductSubcategoryID = sc.ProductSubcategoryID
    INNER JOIN Production.ProductCategory AS c ON sc.ProductCategoryID = c.ProductCategoryID
WHERE 
    p.DiscontinuedDate IS NULL;
GO

CREATE TRIGGER trgInsteadOfDeleteOrders
ON Orders
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;

    -- Delete corresponding records in Order Details table
    DELETE FROM [Order Details]
    WHERE OrderID IN (SELECT OrderID FROM deleted);

    -- Now delete the records from Orders table
    DELETE FROM Orders
    WHERE OrderID IN (SELECT OrderID FROM deleted);
END;
GO


CREATE TRIGGER trgCheckStockBeforeInsert
ON [Order Details]
INSTEAD OF INSERT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ProductID INT;
    DECLARE @Quantity INT;
    DECLARE @UnitsInStock INT;

    -- Loop through each row in the inserted table
    DECLARE InsertCursor CURSOR FOR
    SELECT ProductID, Quantity
    FROM inserted;

    OPEN InsertCursor;

    FETCH NEXT FROM InsertCursor INTO @ProductID, @Quantity;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Get the current stock for the product
        SELECT @UnitsInStock = UnitsInStock
        FROM Products
        WHERE ProductID = @ProductID;

        -- Check if there is enough stock
        IF @UnitsInStock >= @Quantity
        BEGIN
            -- Sufficient stock, perform the insert and update stock
            INSERT INTO [Order Details] (OrderID, ProductID, UnitPrice, Quantity, Discount)
            SELECT OrderID, ProductID, UnitPrice, Quantity, Discount
            FROM inserted;

            -- Update the UnitsInStock
            UPDATE Products
            SET UnitsInStock = UnitsInStock - @Quantity
            WHERE ProductID = @ProductID;
        END
        ELSE
        BEGIN
            -- Insufficient stock, notify the user
            RAISERROR('Insufficient stock for ProductID %d. Order could not be placed.', 16, 1, @ProductID);
        END

        FETCH NEXT FROM InsertCursor INTO @ProductID, @Quantity;
    END

    CLOSE InsertCursor;
    DEALLOCATE InsertCursor;
END;
GO
